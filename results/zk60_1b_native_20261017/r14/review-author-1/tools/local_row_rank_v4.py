"""Exact local mask-row rank precheck on NEW native schema6 observations.

This is NOT the full P1 leakage rank: it omits the joint terminal/column
operator, H's global zero-sum constraints, M, CFS and NL1. No old layout or
toy point is substituted. All coefficients come from native accepted views.
"""
import argparse,hashlib,json,sys
from capture_contract_v4 import arguments as contract_arguments, load as load_contract, sha as file_sha
from pathlib import Path
import numpy as np
HERE=Path(__file__).resolve().parent;P=2**64-2**32+1
ZERO=(0,0);ONE=(1,0)
def add(a,b):return ((a[0]+b[0])%P,(a[1]+b[1])%P)
def mul(a,b):return ((a[0]*b[0]+7*a[1]*b[1])%P,(a[0]*b[1]+a[1]*b[0])%P)
def pair(v):
    assert len(v)==2 and all(isinstance(x,int) and 0<=x<P for x in v)
    return tuple(v)
def eq(points):
    out=[ONE]
    for r in points:
        r=pair(r);one_minus=((1-r[0])%P,(-r[1])%P)
        out=[y for x in out for y in [mul(x,one_minus),mul(x,r)]]
    return out
def rank(matrix):
    a=[list(row) for row in matrix];r=0
    for c in range(len(a[0]) if a else 0):
        pivot=next((k for k in range(r,len(a)) if a[k][c]%P),None)
        if pivot is None:continue
        a[r],a[pivot]=a[pivot],a[r];inv=pow(a[r][c],P-2,P)
        a[r][c:]=[(v*inv)%P for v in a[r][c:]]
        for k in range(r+1,len(a)):
            factor=a[k][c]
            if factor:a[k][c:]=[(v-factor*w)%P for v,w in zip(a[k][c:],a[r][c:])]
        r+=1
        if r==len(a):break
    return r
def coefficients(claim,logn,mask_rows):
    out={}
    for part in claim['parts']:
        offset=part['offset'];log=part['log_size'];coef=pair(part['coefficient']);point=part['point']
        row=offset>>logn
        if log<logn:
            values=[ONE]
        else:
            assert offset%(1<<logn)==0
            count=1<<(log-logn)
            values=eq(point[:log-logn]) if point else [ONE]*count
            assert len(values)==count
        for j,value in enumerate(values):
            if row+j in mask_rows:out[row+j]=add(out.get(row+j,ZERO),mul(coef,value))
    return out
def main():
    parser=argparse.ArgumentParser();parser.add_argument('bundle',type=Path);parser.add_argument('output',type=Path);contract_arguments(parser)
    args=parser.parse_args();directory=args.bundle;out=args.output;assert not out.exists()
    run,pin=load_contract(directory,args.source_pin,args.source_tree,args.expected_blocks)
    blob=np.memmap(directory/'arrays.bin',dtype='u1',mode='r')
    def fp2_array(value):
        if isinstance(value,list):return [pair(v) for v in value]
        assert value['elem']=='fp2' and value['bytes']==value['len']*16
        start=value['offset'];end=start+value['bytes'];assert end<=blob.size
        chunk=memoryview(blob)[start:end];assert hashlib.sha256(chunk).hexdigest()==value['array']
        a=np.frombuffer(chunk,dtype='<u8').reshape(-1,2);assert np.all(a<P)
        return [(int(x),int(y)) for x,y in a]
    reports=[]
    for k in range(run['blocks']):
        stage=json.loads((directory/f'stage{k}.json').read_text())
        for role in stage['roles']:
            rows=role['commitment']['rows'];logn=role['params']['log_cols']
            masks=[r['row'] for r in role['row_roles'] if r['kind']!='data'];mask_set=set(masks)
            assert len(masks)==len(mask_set) and all(0<=i<rows for i in masks)
            claims=[coefficients(c,logn,mask_set) for c in role['claims']]
            matrix=[]
            for group in role['groups']:
                coefs={}
                assert len(group['members'])==len(group['lambdas'])
                for ci,weight in zip(group['members'],group['lambdas']):
                    weight=pair(weight)
                    for row,value in claims[ci].items():coefs[row]=add(coefs.get(row,ZERO),mul(weight,value))
                matrix.extend([[coefs.get(i,ZERO)[axis] for i in masks] for axis in [0,1]])
            prox=fp2_array(role['proximity_rhos']);assert len(prox)==rows
            matrix.extend([[prox[i][axis] for i in masks] for axis in [0,1]])
            target=2*(len(role['groups'])+1);observed=rank(matrix)
            assert observed==target,(k,role['role'],observed,target)
            # Every actual private terminal must retain its own nonsingular
            # reserved pair. The known H sum claim is the single exception.
            sites=set(role['site_rows']);private=0;known=0
            for claim,coefs in zip(role['claims'],claims):
                active=sorted(i for i in coefs if i in sites and coefs[i]!=ZERO)
                if not active:
                    assert role['role']=='H' and claim['value']==[0,0]
                    known+=1;continue
                assert len(active)==2 and active[1]==active[0]+1
                left,right=[coefs[i] for i in active]
                assert right==mul(left,(0,1)) and (left[0]*left[0]-7*left[1]*left[1])%P!=0
                private+=1
            assert known==(1 if role['role']=='H' else 0)
            probe=None
            if role['commitment_kind']=='internal-boundary':
                # A hypothetical loss of one whole site's pair must destroy
                # this tight boundary row span. This is a rank counterfactual,
                # not a malicious receipt or independent privacy approval.
                columns=[masks.index(i) for i in role['site_rows'][:2]]
                bad=[row[:] for row in matrix]
                for row in bad:
                    for c in columns:row[c]=0
                probe=rank(bad);assert probe<target
            reports.append({'stage':k,'role':role['role'],'root':role['commitment']['root'],'rows':rows,
                'mask_rows':len(masks),'clear_group_and_proximity_Fp_rows':target,'local_mask_rank':observed,
                'private_site_pairs_checked':private,'known_H_sum_claims':known,'removed_pair_counterfactual_rank':probe,
                'limitation':'Local row coefficients only; global H constraints, columns/terminal joint rank, M/CFS/NL1/joint-view proof still required'})
    report={'schema':run['schema'],'scope':'Exact native local row-mask rank precheck only; NOT full privacy/rank acceptance.',
        'field_modulus':P,'extension_nonresidue':7,'roles':reports,
        'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'source_pins':run['source_pins'],'source':pin['tree_sha256'],'contract_helper_sha256':file_sha(HERE/'capture_contract_v4.py'),
        'source_manifest_sha256':file_sha(args.source_pin),'privacy_acceptance':False}
    out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'local_roles_checked':len(reports),'privacy_acceptance':False}))
if __name__=='__main__':main()
