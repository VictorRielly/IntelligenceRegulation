"""Native schema6 M budget/functional-order and sumcheck consistency checks.

Uses actual captured schedules and public functionals, never a legacy slot
count. This is not polynomial equivalence, rank, NL1 or privacy acceptance.
"""
import argparse,hashlib,json,re
from pathlib import Path
P=2**64-2**32+1;ZERO=(0,0);ONE=(1,0)
def pair(value):
    assert isinstance(value,(list,tuple)) and len(value)==2
    assert all(type(v) is int and 0<=v<P for v in value),'noncanonical Fp2'
    return tuple(value)
def add(a,b):return ((a[0]+b[0])%P,(a[1]+b[1])%P)
def neg(a):return ((-a[0])%P,(-a[1])%P)
def sub(a,b):return add(a,neg(b))
def mul(a,b):return ((a[0]*b[0]+7*a[1]*b[1])%P,(a[0]*b[1]+a[1]*b[0])%P)
def base(v):return (v%P,0)
def scale(values,c):return [mul(v,c) for v in values]
def sum_weights(n,d):return [base(1<<n),ONE]+[base(1<<(n-1))]*(n*d)
def eval_weights(rho,d):
    product=ONE
    for r in rho:product=mul(product,r)
    out=[ONE,product]
    for r in rho:
        power=ONE
        for _ in range(d):power=mul(power,r);out.append(power)
    return out
def interpolate(values,x):
    total=ZERO
    for i,value in enumerate(values):
        numerator=ONE;denominator=1
        for j in range(len(values)):
            if i!=j:numerator=mul(numerator,sub(x,base(j)));denominator=denominator*(i-j)%P
        total=add(total,mul(value,mul(numerator,base(pow(denominator,P-2,P)))))
    return total
def functional(terms,value):
    return {'terms':[{'slot':s,'weights':[list(w) for w in weights]} for s,weights in terms],'value':list(value)}
def array_length(value):return value['len'] if isinstance(value,dict) else len(value)
def check_stage(stage,profile,*,message_positions=512,pad_positions=256,domain_positions=4096):
    slots=stage['arguments'];specs=stage['mask']['specs'];metadata=profile['slots']
    assert len(slots)==len(specs)==len(metadata)>0
    assert stage['mask']['rows']==profile['m_rows']==2*len(slots)+4
    assert array_length(stage['mask']['q'])==array_length(stage['mask']['prox'])==2*message_positions
    assert len(stage['mask']['columns'])==pad_positions
    expected=[];hosts=[];covered={};rows=[]
    for s,(arg,spec,meta) in enumerate(zip(slots,specs,metadata)):
        main,ext,d=meta['main'],meta['extension'],meta['degree'];n=main+ext
        assert arg['slot']==s==meta['slot'] and spec==[n,d]
        assert (arg['main'],arg['extension'],arg['degree'])==(main,ext,d)
        assert main>0 and ext>0 and d>0
        length=n*d+2;assert length+pad_positions<=message_positions,'CFS mask message budget'
        rho=[pair(v) for v in arg['rho']];assert len(rho)==n
        assert all(v not in [ZERO,ONE] for v in rho[main:]),'degenerate terminal challenge'
        c=pair(arg['c']);assert c!=ZERO,'zero CFS challenge'
        kind=arg['kind'];assert kind in ['Private','Standalone','Host']
        assert bool(arg['hosted'])==(kind=='Host')
        claimed=pair(arg['scalar']);host_terms=[(s,scale(sum_weights(n,d),c))]
        for host in arg['hosted']:
            h=host['slot'];coefficient=pair(host['coefficient'])
            assert 0<=h<s and slots[h]['kind']=='Private'
            covered[h]=covered.get(h,0)+1
            claimed=add(claimed,mul(coefficient,pair(slots[h]['scalar'])))
            hn,hd=specs[h]
            host_terms.append((h,scale(sum_weights(hn,hd),neg(mul(coefficient,pair(slots[h]['c']))))))
        assert claimed==pair(arg['claimed_sum']),'hosted masked scalar binding'
        rounds=arg['rounds'];assert len(rounds)==n
        for j,round_ in enumerate(rounds):
            values=[pair(v) for v in round_];assert len(values)==d+1
            assert add(values[0],values[1])==claimed,('sumcheck consistency',s,j)
            claimed=interpolate(values,rho[j])
        assert claimed==pair(arg['sumcheck_final']),'sumcheck final'
        if kind=='Standalone':expected.append(functional(host_terms,pair(arg['scalar'])))
        if kind=='Host':hosts.append(functional(host_terms,pair(arg['scalar'])))
        expected.append(functional([(s,eval_weights(rho,d))],pair(arg['mask_eval'])))
        rows.append({'slot':s,'base':meta['base'],'part':meta['part'],'kind':kind,'rounds':n,'degree':d,
            'CFS_coefficients':length,'random_pad_positions':pad_positions,'zero_positions':message_positions-length-pad_positions,
            'pad_interval':[length,length+pad_positions],'encoding_domain':domain_positions})
    assert set(covered)=={s for s,arg in enumerate(slots) if arg['kind']=='Private'}
    assert all(count==1 for count in covered.values()),'private scalar hosted more than once'
    expected.extend(hosts)
    assert len(expected)==len(slots)+sum(arg['kind']!='Private' for arg in slots)
    assert stage['mask']['functionals']==expected,'native M functional value/weights/order'
    return {'slots':len(slots),'functionals':len(expected),'private_scalars_hosted_once':len(covered),
        'max_CFS_coefficients':max(r['CFS_coefficients'] for r in rows),'slot_budgets':rows}
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    args=p.parse_args();assert not args.output.exists()
    run=json.loads((args.bundle/'run.json').read_text());assert run['schema']=='hashline-native-capture/6-split-run' and run['fully_verified'] is True
    here=Path(__file__).resolve().parent;pin=json.loads((here/'sol-r14-capture-build-1.source.json').read_text())
    assert {p['file']:p['sha256'] for p in run['source_pins']}==pin['files']
    tree=here/'capture-working-tree'
    for name in ['hashline/src/zk.rs','hashline/src/private_block/argument.rs','zkp-core/src/sumcheck.rs']:
        assert sha(tree/name)==pin['files'][name]
    source=(tree/'hashline/src/zk.rs').read_text()
    def constant(name):return int(re.search(r'pub const '+name+r':\s*\w+\s*=\s*(\d+)\s*;',source).group(1))
    msg=1<<constant('MASK_LOG_MSG');dom=1<<constant('MASK_LOG_DOM');pads=constant('MASK_Q')
    reports=[]
    for k,profile in enumerate(run['profiles']):
        stage=json.loads((args.bundle/f'stage{k}.json').read_text())
        result=check_stage(stage,profile,message_positions=msg,pad_positions=pads,domain_positions=dom)
        result['stage']=k;reports.append(result)
    report={'schema':run['schema'],'source':pin['tree_sha256'],'field_modulus':P,'extension_nonresidue':7,
        'message_positions':msg,'encoding_domain_positions':dom,'random_pad_positions_per_mask_row':pads,
        'stages':reports,'checker_sha256':sha(Path(__file__)),
        'status':'PASS captured native CFS storage budget, exact M functionals/order, host scalar binding and sumcheck consistency',
        'scope':'Source-pinned public accepted verifier observations. No polynomial equivalence, source-map proof, rank/CFS joint leakage, NL1 or full privacy approval.',
        'privacy_acceptance':False}
    args.output.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'stages':len(reports),'status':'PASS limited native M consistency checks','privacy_acceptance':False}))
if __name__=='__main__':main()
