"""Saved-evidence audit. Imports neither candidate nor experiment drivers."""
from pathlib import Path
import hashlib,json
from collections import Counter
from field_support import F
from polynomial_ir import expanded
from source_port import layout
import oracle as o
E=Path(__file__).resolve().parent;checks=Counter()
def ck(ok,name):
    assert ok,name
    checks[name]+=1

for rec in json.loads((E/'native-pins.json').read_text()):
    ck(hashlib.sha256((E/rec['snapshot']).read_bytes()).hexdigest()==rec['sha256'],'native_snapshot_hashes')
for rec in json.loads((E/'local-reference-provenance.json').read_text()):
    ck(hashlib.sha256((E/rec['copy']).read_bytes()).hexdigest()==rec['sha256'],'copied_reference_hashes')
src=(E/'native/02-argument.rs').read_text();gsrc=(E/'native/00-grouped.rs').read_text()
i=src.index('SC_SZC if sh.dd_cap > 0 => {');j=src.index('SC_SZC => {',i)
dd=src[i:j];normal=src[j:src.index('SC_TAB => {',j)]
for name,ok in [('dd_returns_generic_definition','b.finish(Box::new(poly), hosted)' in dd and 'def.groups' not in dd),('non_dd_sets_groups','def.groups = Some((groups, bracket))' in normal),('dd_keyed_tuple','g_dd.add(key).add(beta.mul(mask.mul(e))).add(beta2.mul(p))' in dd),('all_tables_cur_dif','for (t, tb) in self.tables.iter().enumerate()' in gsrc),('all_tables_fold','for tb in self.tables.iter_mut()' in gsrc),('native_sums_start_from_actual_claims','claims: vec![None; count]' in gsrc)]:ck(ok,name)

fixtures=json.loads((E/'fixtures.json').read_text())
for f in fixtures:
    k=f['k'];M=(1<<f['n'])-1;d=4 if f['padded'] else 3
    for key,wanted in [('distinct_endpoint_reads',6*M),('difference_sub',3*M),('interpolation_add',3*d*M)]:
        ck(f['base_counts'].get(key,0)-f['candidate_counts'].get(key,0)==wanted,'non_dd_closed_counts')
    ck(f['candidate_records']==[] or f['candidate_records'][0]['last']==[-1]*3+[d]*(k-3),'non_dd_live_union')
    for tab,wanted in zip(f['tables'],f['finals']):ck(list(o.mle(tab,f['challenges']))==wanted,'non_dd_direct_finals')
    if f['n']==3 and f['mode']=='full':
        cfg=layout(ls=f['ls'],padded=f['padded']);const={k:F(*v) for k,v in f['constants'].items()};ir=expanded(cfg,const)
        prefix=[]
        for j,vals in enumerate(f['round_group_vectors']):
            want=[o.round_direct(f['tables'],list(enumerate(ir)),prefix,t,f['n']) for t in range(d+2)]
            saved=[(0,0)]*(d+2)
            for group in vals:saved=[o.add(a,b) for a,b in zip(saved,group)]
            ck(want==saved,'non_dd_saved_round_replay');prefix.append(f['challenges'][j])

# Independent DD expanded equations without importing dd_projection.
from polynomial_ir import Poly
def dd_ir(f):
    ix=f['cfg']['index'];x=lambda n:Poly.var(ix[n]);c=lambda n:Poly.scalar(f['constants'][n])
    m,s,z,e,p,ma,su=(x(n) for n in ['mask','s8','zsel','e','p','mx','sum'])
    delta=ma-m*(s+127)+127
    cx=x('hx')*(c('alpha')-delta-c('beta')*e-c('gexp'))-1
    ct=x('ht')*(c('alpha')-c('gdd')-su-c('beta')*m*e-c('beta')*c('beta')*p)-1
    dens=[c('alpha')-c('gu8')-(s+127),c('alpha')-c('gu8')-(-s+127),c('alpha')-c('gu8')-x('rsl'),c('alpha')-c('gu8')-4*x('rsl')]
    h=Poly.scalar(0)
    for k in range(2):h+=c('mu'+str(k+2))*(x('h'+str(k))*dens[2*k]*dens[2*k+1]-dens[2*k]-dens[2*k+1])
    polys=[h+c('mu4')*cx+c('mu5')*ct+c('mu0')*(z*z-z)+c('mu1')*z*delta,c('nu0')*(su+c('lam')),c('nu1')*(64*s+x('rsl')-32)]
    return [[(F(*coef),mon) for mon,coef in sorted(poly.terms.items())] for poly in polys]

for f in json.loads((E/'dd-fixtures.json').read_text()):
    ir=dd_ir(f);prefix=[]
    for j,roundv in enumerate(f['rounds']):
        want=[o.round_direct(f['tables'],list(enumerate(ir)),prefix,t,f['n']) for t in range(5)]
        ck([list(x) for x in want]==roundv,'independent_dd_round_replay');prefix.append(f['challenges'][j])
    for tab,wanted in zip(f['tables'],f['finals']):ck(list(o.mle(tab,f['challenges']))==wanted,'dd_direct_finals')
    ck(len(f['tables'])==15,'dd_table_order_count')

for f in json.loads((E/'dd-costs.json').read_text()):
    generic=Counter();grouped=Counter()
    for j in range(f['n']):
        m=1<<(f['n']-j-1);rec=int(f['recovery'] and j>0);S=5-rec;G0=4-rec;G1=G2=2-rec
        generic.update(mul=m*(27*S+15),add=m*(24*S+75),sub=m*(13*S+30),mul_base=m*5*S)
        grouped.update(mul=m*(21*G0+3*G1+3*G2+18),add=m*(20*G0+2*G1+2*G2+60),sub=m*(12*G0+G2+30),mul_base=m*(4*G0+G2))
    ck(dict(generic)==f['generic_scan_fold'],'independent_generic_operation_formula')
    ck(dict(grouped)==f['grouped_scan_fold'],'independent_grouped_operation_formula')
    ck(all(generic[k]-grouped[k]==v for k,v in f['removed_scan_fold'].items()),'independent_dd_removed_counts')

result=dict(status='PASS',checks=dict(checks),total_checks=sum(checks.values()),imports_candidate=False,imports_experiment=False,native_execution=False,cryptographic_verification=False)
(E/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
