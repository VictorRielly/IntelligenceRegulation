"""Conditional R14 backend recount using authenticated actual26-layer headers.

No model-weight sweep, classifier term, registration, or review acceptance.
"""
from datetime import datetime,timezone
import hashlib,json,math,struct
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
EXPORT=HERE.parent/'r13/shieldstral-export-v2'
P=2**64-2**32+1;FIELD=P*P
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path,maximum=1<<20):
    assert path.is_file() and path.stat().st_size<=maximum,path
    return path.read_bytes()
def main():
    profile_path=EXPORT/'profile.json'
    assert sha(profile_path)=='1d50078243f13d58afa814a55c47c2df797e494d7f045941ea82fa142740498a'
    profile=json.loads(read(profile_path));assert profile['T']==256 and len(profile['layers'])==26
    pins={str(profile_path.relative_to(ROOT)):sha(profile_path)};layers=[]
    for ordinal,item in enumerate(profile['layers']):
        assert item['layer']==ordinal
        path=EXPORT/item['dir']/'manifest.json'
        assert sha(path)==item['manifest_sha256'];pins[str(path.relative_to(ROOT))]=sha(path)
        manifest=json.loads(read(path));assert manifest['layer']==ordinal
        groups=[];ids=[]
        for key in ['silu_groups','silu_group_ids']:
            spec=manifest['arrays'][key];assert spec['dtype']=='int64'
            file=path.parent/spec['file'];raw=read(file)
            assert hashlib.sha256(raw).hexdigest()==spec['sha256']
            assert len(raw)==8*math.prod(spec['shape'])
            values=list(struct.unpack('<'+'q'*(len(raw)//8),raw))
            pins[str(file.relative_to(ROOT))]=spec['sha256']
            if key=='silu_groups':
                assert len(spec['shape'])==2 and spec['shape'][1]==2 and 1<=spec['shape'][0]<=4
                groups=[values[i:i+2] for i in range(0,len(values),2)]
            else:
                assert spec['shape']==[9216];ids=values
        assert all(0<=g<len(groups) for g in ids)
        c=manifest['constants'];assert c['f_p']==12 and 9<=c['f_e']<=16
        layers.append({'layer':ordinal,'manifest_sha256':item['manifest_sha256'],'groups':groups,
            'group_populations':[ids.count(i) for i in range(len(groups))],
            'narrow_group_populations':[ids[8192:].count(i) for i in range(len(groups))],
            'constants':c})
    native_path=HERE/'NATIVE_BUILDERS_CENSUS.json';native=json.loads(read(native_path,8<<20))
    variants=[]
    for tokens in [128,256]:
        for dd in [False,True]:
            stages=[];n=1<<(14 if tokens==128 else 15);queries=256;rate=4
            inventory=[r for r in native['inventory'] if r['tokens']==tokens and r['dd']==dd]
            assert len(inventory)==3
            for layer in layers:
                fe=layer['constants']['f_e'];limbs=(tokens.bit_length()-1+fe+7)//8
                matching=[r for r in inventory if (tokens.bit_length()-1+r['f_e']+7)//8==limbs]
                assert matching,'no native census for this remainder class'
                ref=matching[0]
                assert all(r['byte_queries']==ref['byte_queries'] for r in matching)
                exp=32*tokens*tokens;act=tokens*9216;ddq=exp if dd else 0;ddtable=32*tokens*32 if dd else 0
                N=ref['byte_queries']+exp+act+ddq;Td=512+4096*len(layer['groups'])+ddtable
                stages.append({'layer':layer['layer'],'f_e':fe,'native_census_f_e':ref['f_e'],'groups':len(layer['groups']),
                    'byte_queries':ref['byte_queries'],'exp_queries':exp,'act_queries':act,'dd_queries':ddq,
                    'N':N,'T_d':Td,'lookup_error':(N+4*Td-1)/FIELD,
                    'sumcheck_round_degree_ceiling':8192,'pcs_field_numerator_ceiling':4096})
            L=len(stages);regular=3*L+1
            column=regular*(1-(1-(n+queries)/(n*rate))/3)**queries+L*.75**queries
            erasure=(n*rate-(n+queries))//3
            pcs=(regular*(erasure+1+4096)+L*(1025+4096))/FIELD
            sc=L*8192/FIELD;lookup=sum(s['lookup_error'] for s in stages)
            variants.append({'tokens':tokens,'dd':dd,'layers':L,'regular_openings':regular,'mask_openings':L,
                'stages':stages,'lookup_error':lookup,'column_error':column,'pcs_field_error_ceiling':pcs,
                'sumcheck_error_ceiling':sc,'conditional_backend_bits':-math.log2(lookup+column+pcs+sc)})
    # Each split dot/norm is still ONE full true-width sum and ONE rounding.
    # These deliberately retain R13's conservative class/window maxima.
    D,F,Q=3072,9216,4096;X=Y=1<<15;W=127;H=1<<23
    bounds={
        'norm_square_full_true_width':D*X*X+(1<<40),
        'qkv_host':2*D*Y*W*(1<<6)+(1<<17)*(1<<16),
        'gate_host':2*D*Y*W*(1<<14)+(1<<13)*(1<<24),
        'ao_host':2*Q*Y*W*(1<<8)+(1<<17)*(1<<24),
        'up_host':2*D*Y*W*(1<<4)+(1<<17)*(1<<16),
        'down_host':2*F*H*W*(1<<6)+(1<<17)*(1<<24),
        'norm_quotient':4*X*W*(1<<20)+4*math.isqrt((1<<40)+D*X*X)*Y*(1<<8)+(1<<25),
        'h24_product':2*((1<<15)-1)*(1<<16)*(1<<15)+4*H*(1<<16)+(1<<18),
    }
    assert all(0<v<P for v in bounds.values())
    report={'utc':datetime.now(timezone.utc).isoformat(),'scope':'COUNTED conditional native R14 backend at authenticated actual26S2 layer calibrations and group counts, T128/T256±DD. No classifier/token stages, R14 security tier, review acceptance or registration.',
        'actual_layers':layers,'variants':variants,
        'no_wrap':{'scope':'Conservative true-width clauses with unchanged R13 validator maxima; assumes native physical range/host relations enforce the counted classes. Author count, not independent review.',
            'field_modulus':P,'width':D,'hidden':F,'query_width':Q,'clauses':{k:{'absolute_bound':v,'bits':math.log2(v),'below_field':v<P} for k,v in bounds.items()},
            'rounding':'One full sum across both physical pieces before one original R13 rounding; no private partial accumulator/remainder.'},
        'pending':['Independent transfer of reviewed R13 lookup nonzero-residue/degree2 lemma to native split supports and joint H audit',
            'Native source/capture check of conservative PCS/M field and CFS ceilings',
            'Whole classifier/token composition before any min-bits or registration decision',
            'Native capture/rank/NL1/joint-view privacy gate remains separate'],
        'source_sha256':{**pins,str(native_path.relative_to(ROOT)):sha(native_path),
            str(Path(__file__).resolve().relative_to(ROOT)):sha(Path(__file__))}}
    (HERE/'ACTUAL_26_LAYER_CONDITIONAL_COUNT.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps([{'tokens':v['tokens'],'dd':v['dd'],'conditional_backend_bits':v['conditional_backend_bits']} for v in variants]))
if __name__=='__main__':main()
