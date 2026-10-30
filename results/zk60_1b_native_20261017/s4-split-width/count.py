"""Anchor native R13 storage, then count two explicit split constructions.

Baseline counts are exact against frozen native output. New claim schedules
and memory extrapolations are proposals, not native measurements or acceptance.
"""
from pathlib import Path
from collections import Counter
import csv
import hashlib
import json

HERE=Path(__file__).resolve().parent
R13=HERE.parent/'r13'

def native(dd,ls):
    records=[s.split(',') for s in (HERE/'s4-native-role-census.log').read_text().splitlines()]
    records=[r for r in records if r[1:3]==[str(dd).lower(),str(ls)]]
    a=Counter(r[4] for r in records if r[0]=='ROLE')
    lk={r[3]:int(r[4]) for r in records if r[0]=='LOOKUPS'}
    h={d:(n+1)//2 for d,n in lk.items() if n}
    h['S']+=1+int(dd);h['F']+=1;h['Tab']=4
    if dd:h['Dd']+=1
    return a,h,lk

def main():
    census=json.loads((R13/'NATIVE_LAYOUT_CENSUS.json').read_text())['rows'];rows=[]
    for old in census:
        if 'shieldstral' not in old['profile'] or old['f_e']!=9 or old['groups']!=4:continue
        T,N,dd=old['tokens'],old['n'],old['dd'];ls=(9+T.bit_length()-1+7)//8
        a,h,lk=native(dd,ls)
        size={'T':T,'Ht':32*T,'L':N,'D':4096*T,'Q':4096*T,'Kv':1024*T,
              'S':32*T*T,'F':16384*T,'Tab':N,'Dd':32*T*32}
        storage=lambda counts:sum(n*max(1,size[d]//N) for d,n in counts.items())
        adata,hdata=storage(a),2*storage(h)
        assert adata==old['a_mask_base'] and hdata==old['h_mask_base'],(T,dd,adata,hdata)
        A=adata+2*old['a_sites']+2;H=hdata+2*old['h_sites']+2
        assert (A,H)==(old['a_rows'],old['h_rows'])
        byte=sum(size[d]*n for d,n in lk.items());assert byte==old['byte_queries']
        baseline=(A+H)*N
        raw_saved=(4096-3072)*T*(a['D']+2*h['D'])+(16384-9216)*T*(a['F']+2*h['F'])
        qsave=(4096-3072)*T*lk['D']+(16384-9216)*T*lk['F']
        for variant,extra_a,extra_h,extra_slots,partials in [
            ('batched_zero_lift',74,25,8,0),
            ('explicit_partial_planes',85,25,19,T*(4096+2*1024+2*9216+3072)+2*N),
        ]:
            masks=2*(extra_a+extra_h)*N
            words=baseline-raw_saved+masks+partials
            mrows=old['m_rows']+2*extra_slots
            assert words>0 and (T*1024)>=N
            measured_peak=7.54 if dd else 7.67
            anchor=next(x for x in census if 'shieldstral' in x['profile'] and x['tokens']==128 and x['dd']==dd and x['f_e']==9 and x['groups']==4)
            anchor_words=(anchor['a_rows']+anchor['h_rows'])*anchor['n']
            peak_models={str(fixed):fixed+(measured_peak-fixed)*words/anchor_words for fixed in [0,.5,1,2]}
            row={'tokens':T,'dd':dd,'variant':variant,'n':N,'baseline_a_h_words':baseline,
                 'split_a_h_words':words,'a_h_saving_percent':100*(1-words/baseline),
                 'raw_data_saved_words':raw_saved,'extra_claim_mask_words':masks,'partial_data_words':partials,
                 'extra_a_sites':extra_a,'extra_h_sites':extra_h,'extra_slots':extra_slots,
                 'baseline_m_rows':old['m_rows'],'split_m_rows':mrows,
                 'baseline_byte_queries':byte,'split_byte_queries':byte-qsave,
                 'baseline_act_queries':old['act_queries'],'split_act_queries':T*9216,
                 'baseline_endpoint_rows_each':old['endpoint_rows'],'split_endpoint_rows_each':T*3072//N+2*5,
                 'peak_gib_model_by_fixed_gib':peak_models,
                 'scope':'COUNTED proposed role/claim schedule; memory MODEL from one shared-host R13 actual-L00/T128 peak, not a fit guarantee'}
            rows.append(row)
    assert len(rows)==8
    report={'anchor_source':'R13 bb9eb2123c9350c738dafd19fe3b0133d6e2e7ab93f1e765cac4f20ccaed69ec',
            'anchor_census_sha256':hashlib.sha256((R13/'NATIVE_LAYOUT_CENSUS.json').read_bytes()).hexdigest(),
            'native_role_log_sha256':hashlib.sha256((HERE/'s4-native-role-census.log').read_bytes()).hexdigest(),
            'native_baselines_reproduced':4,'rows':rows,'guard_budget_gib':11.89,
            'warning':'R12 padding-saving percentages and T256 fit estimates do not establish an R13 fit; fixed scratch/live-buffer costs and declaration margin remain unmeasured',
            'claim_budgets':{'batched_zero_lift':{'A':{'DZC':41,'FZC':16,'norm_sums':2,'QKV':3,'WO':1,'G_and_U':6,'down':3,'IO':2},'H':{'DZC':17,'FZC':8},'slots':{'DZC_FZC':2,'WO_G_U_down':4,'IO':2}},
                            'explicit_partial_planes':{'A':{'DZC_including_partial':43,'FZC_including_partials':20,'QZC_KVZC_partials':3,'TZC_partial_sums':2,'norm_sums':2,'QKV':3,'WO':1,'G_and_U':6,'down':3,'IO':2},'H':{'DZC':17,'FZC':8},'slots':{'matmul':13,'norm_sums':2,'DZC_FZC':2,'IO':2}}}}
    for variant,budget in report['claim_budgets'].items():
        example=next(x for x in rows if x['variant']==variant)
        assert sum(budget['A'].values())==example['extra_a_sites']
        assert sum(budget['H'].values())==example['extra_h_sites']
        assert sum(budget['slots'].values())==example['extra_slots']
    (HERE/'COUNT.json').write_text(json.dumps(report,indent=2)+'\n')
    with (HERE/'COUNT.csv').open('w') as f:
        keys=[k for k in rows[0] if k not in ['peak_gib_model_by_fixed_gib','scope']]
        writer=csv.DictWriter(f,keys,extrasaction='ignore');writer.writeheader();writer.writerows(rows)
    print(json.dumps([{'T':x['tokens'],'DD':x['dd'],'variant':x['variant'],'saving_percent':round(x['a_h_saving_percent'],2),
        'peak_gib_model_range':[round(min(x['peak_gib_model_by_fixed_gib'].values()),2),round(max(x['peak_gib_model_by_fixed_gib'].values()),2)]} for x in rows]))

if __name__=='__main__':main()
