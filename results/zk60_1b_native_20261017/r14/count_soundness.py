"""Provisional D27 backend count. No R14 tier/profile registration.
The reviewed R13 lookup lemma and conservative field/composition ceilings
still require independent transfer to native R14 before any security claim.
"""
import hashlib,json,math
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
P=2**64-2**32+1;FIELD=P*P;L=26;Q=MQ=256;RATE=4

def main():
    native=json.loads((HERE/'NATIVE_BUILDERS_CENSUS.json').read_text());rows=[]
    for c in native['inventory']:
        t=c['tokens'];n=c['n'];dd=c['dd'];exp=32*t*t;act=t*9216;ddq=exp if dd else 0;ddtable=32*t*32 if dd else 0
        queries=c['byte_queries']+exp+act+ddq
        assert queries<2**32
        for groups in [1,2,3,4]:
            td=512+4096*groups+ddtable
            lookup=L*(queries+4*td-1)/FIELD
            old_form=L*2*(queries+td-1)/FIELD
            # One joint commitment per endpoint/boundary: 2L A/H roots,
            # L-1 internal roots and2external roots, and L separate M roots.
            regular_roots=3*L+1;all_roots=4*L+1
            column=regular_roots*(1-(1-(n+Q)/(n*RATE))/3)**Q+L*.75**MQ
            erasure=(n*RATE-(n+Q))//3
            pcs=(regular_roots*(erasure+1+4096)+L*(1025+4096))/FIELD
            sc=L*8192/FIELD;total=lookup+column+pcs+sc
            rows.append({'base_profile':c['base_profile'],'tokens':t,'f_e':c['f_e'],'dd':dd,'act_groups':groups,
                'blocks':L,'regular_openings':regular_roots,'mask_openings':L,'total_commitments':all_roots,
                'byte_queries':c['byte_queries'],'exp_queries':exp,'act_queries':act,'dd_queries':ddq,'N_queries':queries,'T_d':td,
                'lookup_error':lookup,'column_error':column,'pcs_field_error_ceiling':pcs,'sumcheck_error_ceiling':sc,
                'conditional_whole_bits':-math.log2(total),'lookup_only_bits':-math.log2(lookup),
                'older_conservative_lookup_form_bits':-math.log2(old_form),
                'scope':'COUNTED conditional backend bound, constant admitted calibration; no classifier/token stages or actual26layer calibration census; unregistered/unreviewed R14'})
    report={'scope':'Provisional D27 count only; no R14 security tier accepted or registered. Applies reviewed R13 N+4Td-1 lookup formula to actual true-piece native query counts and unchanged Pcs/M parameters, with conservative4096field/8192SC ceilings from the earlier lever count.',
        'rows':rows,'minimum_conditional_bits':min(r['conditional_whole_bits'] for r in rows),
        'obligations':['Independently confirm R13 lookup nonzero-residue/degree-2 collision lemma under the native split H sum and supports',
            'Confirm PCS/M field/composition ceilings and refusals from complete native source/captures',
            'Recount actual ordered per-layer calibration and all token/classifier stages before any registration/min-bits decision',
            'Native joint/rank/CFS/NL1 privacy gate remains separate; no inherited privacy acceptance'],
        'key_correction':'Joint roots keep opening count unchanged at3L+1regular plusL M. Extra piece claim groups change receipt/rank/field census; the earlier separate-piece-root +L+1opening cost does not apply.',
        'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [HERE/'NATIVE_BUILDERS_CENSUS.json',ROOT/'results/zk60_d24_review_20261017/r13/reviewer_bits_r13.py',ROOT/'results/zk60_sol_20261026/r13-security-levers/count.py']}}
    (HERE/'PRELIMINARY_SOUNDNESS_COUNT.json').write_text(json.dumps(report,indent=2)+'\n')
    for t in [128,256]:
        for dd in [False,True]:
            selected=[r for r in rows if r['tokens']==t and r['dd']==dd]
            print(t,dd,'conditional bits',min(r['conditional_whole_bits'] for r in selected),'to',max(r['conditional_whole_bits'] for r in selected))
if __name__=='__main__':main()
