"""Exact byte formulas from compiled R14 census and native R13 lengths.
Constant admitted FE9/G20 calibration examples, not actual26layer exports.
"""
import hashlib,json
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];R13=HERE.parent/'r13'

def main():
    native=json.loads((HERE/'NATIVE_BUILDERS_CENSUS.json').read_text())
    prior=json.loads((R13/'NATIVE_COMPARISON.json').read_text())['rows'];rows=[]
    for groups in native['groups']:
        profile=groups['base'];shape=next(r for r in native['inventory'] if r['base_profile']==profile and r['f_e']==9)
        old=next(r for r in prior if r['profile']==profile);n=shape['n'];q=256;rate=4;path=(n*rate).bit_length()-1
        def opening(g,r):return (g+1)*(n+q)*16+q*(8+r*8+32+path*32)
        slots=[r for r in native['slot_definitions'] if r['base']==profile]
        slot_bytes=sum((1+(s['main']+s['ext'])*(s['degree']+1)+s['terminals'])*16 for s in slots)
        mask_bytes=2*1024*16+q*(8+shape['m_rows']*8+32+12*32)
        new_body=3*32+slot_bytes+mask_bytes+opening(groups['a_groups'],shape['a_rows'])+opening(groups['h_groups'],shape['h_rows'])
        old_body=old['receipt_bytes']-40-2*opening(1,37)
        new_external=opening(2,shape['joint_external_rows']);new_boundary=opening(4,shape['joint_internal_rows'])
        old_external=opening(1,37);old_boundary=opening(2,38)
        for l in [2,26]:
            before=l*(88+old_body+32)+(l-1)*32+2*old_external+(l-1)*old_boundary
            after=l*(120+new_body+32)+(l-1)*32+2*new_external+(l-1)*new_boundary
            new_first=120+32+new_body+new_external+32
            new_last=120+new_body+new_boundary+new_external+32
            new_middle=120+32+new_body+new_boundary+32
            assert after==new_first+new_last+(l-2)*new_middle
            rows.append({'base_profile':profile,'tokens':shape['tokens'],'dd':shape['dd'],'blocks':l,
                'n':n,'pcs_queries':q,'inv_rate':rate,'a_groups':groups['a_groups'],'h_groups':groups['h_groups'],
                'r13_segment_total_bytes':before,'r14_segment_total_bytes':after,'increase_bytes':after-before,
                'increase_percent':100*(after/before-1),'r14_first_segment_bytes':new_first,'r14_last_segment_bytes':new_last,'r14_interior_segment_bytes':new_middle,
                'a_h_saving_percent':100*(1-shape['a_h_words']/shape['base_a_h_words']),
                'scope':'COUNTED exact codec formula, constant admitted FE9/G20 calibration example; no actual26layer export/throughput/privacy claim'})
    sources=[HERE/'NATIVE_BUILDERS_CENSUS.json',R13/'NATIVE_COMPARISON.json',R13/'frozen-tree/hashline/src/private_block/shape.rs',R13/'frozen-tree/hashline/src/private_block/wire.rs',
        HERE/'working-tree/hashline/src/private_block/split_wire.rs']
    checks=[]
    for mode in ['non-dd','dd']:
        directory=HERE/'stream-fixtures'/mode
        if all((directory/f'segment{k}.bin').is_file() for k in range(2)):
            row=next(r for r in rows if r['tokens']==128 and r['dd']==(mode=='dd') and r['blocks']==2)
            observed=[(directory/f'segment{k}.bin').stat().st_size for k in range(2)]
            counted=[row['r14_first_segment_bytes'],row['r14_last_segment_bytes']]
            assert observed==counted,(mode,observed,counted)
            checks.append({'mode':mode,'observed_bytes':observed,'counted_bytes':counted,'sum_bytes':sum(observed)})
    serialized={'status':'PASS DD/nonDD2stage native files equal first/last codec formula exactly' if len(checks)==2 else 'partial/pending native serialized files','cases':checks}
    report={'scope':'Native compiled role/slot/group census plus accepted native R13 receipt lengths. Exact codec formulas; all stages share census calibration. Token/classifier stages and statement sidecars excluded.',
        'rows':rows,'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},
        'finding':'Fewer A/H committed words do not imply smaller proof bytes. More independent column-key groups add Fp2 vectors; one joint commitment still opens each piece claim group.',
        'native_serialized_length_check':serialized}
    (HERE/'RECEIPT_TRADEOFF.json').write_text(json.dumps(report,indent=2)+'\n')
    for r in rows:
        if r['blocks']==26:print(r['tokens'],'DD' if r['dd'] else 'nonDD',f"A/H {-r['a_h_saving_percent']:.2f}% receipt +{r['increase_percent']:.2f}%",r['r13_segment_total_bytes'],r['r14_segment_total_bytes'])
if __name__=='__main__':main()
