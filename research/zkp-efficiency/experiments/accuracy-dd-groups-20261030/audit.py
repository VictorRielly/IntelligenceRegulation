"""Standalone original-cube, source-contract and count audit.

Imports the separately authored expanded reference only, never engine/driver.
"""
from pathlib import Path
from collections import Counter
import hashlib,json,time
import reference as r

E=Path(__file__).resolve().parent
def main():
    start=time.monotonic();checks=Counter()
    pins=json.loads((E/'source-pins.json').read_text())
    for p in pins:
        b=(E.parents[1]/p['snapshot']).read_bytes()
        assert hashlib.sha256(b).hexdigest()==p['sha256'];checks['source_snapshot_pins']+=1
    paths={p['path']:E.parents[1]/p['snapshot'] for p in pins}
    get=lambda suffix:next(p.read_text() for name,p in paths.items() if name.endswith(suffix) and 'final-working-tree' in name)
    accuracy=get('argument_accuracy.rs');dd=accuracy[accuracy.index('fn szc_dd('):accuracy.index('\nfn szc(',accuracy.index('fn szc_dd('))]
    for needle in ['SC_SZC if sh.dd_cap>0=>szc_dd(ctx,pts,tr).map(Some)',
                   'role(&b,low,L::Rs)?','let mu = tr.challenge_fp2_vec(2 + n_help + 2)',
                   'precision.score','if pad_on {','let keyed = !dd_lapse(DD_LAPSE_DROP_KEY)',
                   'let key = if keyed { sum } else { Fp2::ZERO }',
                   'g_dd.add(key).add(beta.mul(mask.mul(e))).add(beta2.mul(p))',
                   'b.finish(Box::new(poly), hosted)']:
        assert needle in accuracy;checks['source_contract']+=1
    arg=get('/argument.rs')
    assert 'groups: None' in arg
    assert 'accuracy::define_changed' in arg
    assert '(kind == SlotKind::Host) == def.hosted.is_empty()' in arg
    assert 'let unmasked_claim = if kind == SlotKind::Private' in arg
    assert 'let hosted = vec![(SC_RS, nu[0].mul(k(per_row))), (SC_SCORE, nu[1])]' in dd
    checks['host_first_round_full']=1
    layout=get('accuracy_layout.rs');precision=get('accuracy_precision.rs')
    for needle in ['x.group(Dom::S,Limbs::Rs,"RSL",3,A_RSL,1)',
                   'bytes(Limbs::Rs,Some(p.score))?',
                   'v.insert(0,Lk{terms:vec![(self.map[A_S8],-1)],cst:127})',
                   'v.insert(0,Lk{terms:vec![(self.map[A_S8],1)],cst:127})']:
        assert needle in layout;checks['source_contract']+=1
    assert 'p.score += 12' in precision and '(17..=24).contains(v)' in precision
    assert '(1..=8).contains(&base.score)' in precision
    assert [x+12 for x in range(1,9) if 17<=x+12<=24]==[17,18,19,20]
    checks['precision_range']=1
    fixtures=json.loads((E/'fixtures.json').read_text())
    for f in fixtures:
        assert len(f['tables'])==18 and len(f['constants'])==16
        assert list(map(len,f['points']))==[f['n'],f['span'],f['n']]
        poly=r.polynomial(f['constants'],f['shift']);prefix=[]
        for j,ch in enumerate(f['challenges']):
            for t in range(5):
                value=r.direct_round(f['tables'],poly,prefix,t,f['n'])
                assert list(value)==f['rounds'][j][t];checks['round_values']+=1
            prefix.append(tuple(ch))
            remaining=f['n']-j-1
            for tb,saved_fold in zip(f['tables'],f['folds'][j]):
                for tail,value in enumerate(saved_fold):
                    expected=r.mle(tb,prefix+[(b,0) for b in r.bits(tail,remaining)])
                    assert list(expected)==value;checks['folded_values']+=1
        for tb,final in zip(f['tables'],f['finals']):
            assert list(r.mle(tb,prefix))==final;checks['ordered_finals']+=1
        assert max(map(len,poly.terms))==4
        checks['full_degree']+=1
    # Reexecute all pointwise mutations with the distinguishing saved row.
    f=fixtures[0]
    controls=json.loads((E/'negative-controls.json').read_text())
    for c in controls:
        if c['mutation']=='swap_ordered_rs_finals':
            swapped=list(f['finals']);swapped[6],swapped[7]=swapped[7],swapped[6]
            assert c['truth']==f['finals'] and c['mutated']==swapped and swapped!=f['finals']
        else:
            v=[tuple(tb[c['row']]) for tb in f['tables']]
            truth=r.polynomial(f['constants'],f['shift']).at(v)
            bad=r.polynomial(f['constants'],f['shift'],c['mutation']).at(v)
            assert truth!=bad and list(truth)==c['truth'] and list(bad)==c['mutated']
            if c['mutation']=='drop_tuple_mask':assert v[3]==r.Z
        checks['reexecuted_controls']+=1
    costs=json.loads((E/'cost-census.json').read_text())
    assert costs['bracket_ops']==[dict(add=23,mul=23,sub=15,mul_base=6),dict(mul=2,add=1),dict(mul=5,add=4,mul_base=1,sub=1)]
    # Independent closed counts: full polynomial has 33mul/31add/16sub/7base
    # plus accumulator; each row also pays differences, folds and updates.
    expand=lambda c:5*c.get('mul',0)+2*c.get('mul_base',0)+c.get('base_mul',0)+127*c.get('base_inv',0)+132*c.get('inv2',0)
    for row in costs['rows']:
        n=row['n'];S=5*(1<<(n-1))+4*((1<<(n-1))-1);pairs=(1<<n)-1
        expected=Counter(mul=33*S+18*pairs+25*n,add=31*S+90*pairs+5*n,
                         sub=16*S+36*pairs+n-1,mul_base=7*S+5*n,
                         sub_base=20*n,base_mul=20*n,base_inv=5*n)
        assert expected==Counter(row['before_api']),(row['n'],expected, row['before_api'])
        for key in ['before','after']:
            assert expand(row[key+'_api'])==row['expanded_base_products_'+key];checks['expanded_products']+=1
        assert row['removed']==expand(row['before_api'])-expand(row['after_api'])
        checks['generic_closed_count']+=1
    candidate=(E/'argument_accuracy.candidate.rs').read_text()
    original_dd=dd[dd.index('            let poly = move'):dd.index('            b.finish')]
    changed=candidate[candidate.index('fn szc_dd('):candidate.index('\nfn szc(',candidate.index('fn szc_dd('))]
    candidate_poly=changed[changed.index('            let poly = move'):changed.index('            let mut def')]
    assert original_dd==candidate_poly
    assert 'if ght.0.is_none() && gs.0.is_none() {' in changed
    assert 'bracket_degree: 3' in changed and changed.count('bracket_degree: 1')==2
    assert hashlib.sha256(original_dd.encode()).hexdigest()==json.loads((E/'patch-contract.json').read_text())['poly_sha256']
    checks['uncompiled_patch_contract']=4
    out=dict(status='PASS',checks=dict(checks),wall_s=time.monotonic()-start,proofs=0,proved_positions=0,
             scope='Locally independent algebra/count/source audit, not external review or native cryptographic verification.')
    (E/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
if __name__=='__main__':main()
