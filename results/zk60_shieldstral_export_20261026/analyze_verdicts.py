"""Pair S2 integer verdicts with A1 float results; keep refusals explicit."""
import argparse
import json
from pathlib import Path
import numpy as np
from collect_stats import sha,atomic_json

HERE=Path(__file__).resolve().parent
PREP=HERE.parent/'zk60_shieldstral_prep_20261021'
CATEGORIES={'sexual':['S','S3'],'violence':['V','V2'],'hate':['H','HR','H2']}


def metric(truth,prediction,weights):
    truth=np.asarray(truth,dtype=bool);prediction=np.asarray(prediction,dtype=bool);weights=np.asarray(weights,dtype=float)
    tp=float(weights[truth&prediction].sum());fp=float(weights[~truth&prediction].sum());fn=float(weights[truth&~prediction].sum())
    ratio=lambda a,b:a/b if b else None
    return {'precision':ratio(tp,tp+fp),'recall':ratio(tp,tp+fn),'f1':ratio(2*tp,2*tp+fp+fn),
            'tp_weight':tp,'fp_weight':fp,'fn_weight':fn,'n':len(truth)}


def paired(rows,float_rows,head):
    weights=np.array([r['weight'] for r in rows],dtype=float)
    fm=np.array([float_rows[r['id']]['margin'] for r in rows],dtype=float)
    im=np.array([r['heads'][head]['margin_real'] for r in rows],dtype=float)
    flags=np.array([r['heads'][head]['flagged'] for r in rows],dtype=bool)
    refused=np.array([r['stack_refused'] or r['heads'][head]['head_refused'] for r in rows],dtype=bool)
    if not np.isfinite(fm).all() or not np.isfinite(im).all() or not np.isfinite(weights).all() or np.any(weights<=0):
        raise ValueError('nonfinite margins or invalid weights')
    if any(float_rows[r['id']]['n_content_tokens']!=r['content_tokens'] or float_rows[r['id']]['T']!=r['T'] for r in rows):
        raise ValueError('integer/float prompt lengths differ')
    for row in rows:
        reference=float_rows[row['id']]
        if (row['weight']!=reference.get('weight',1.) or row.get('label')!=reference.get('label')
                or row.get('cats',[])!=reference.get('cats',[]) or row.get('known',[])!=reference.get('known',[])):
            raise ValueError('integer/float labels or sampling weights differ')
    category=rows[0]['template'].split('_',1)[1];keys=CATEGORIES[category]
    truth=np.array([r['label']==1 if r['dataset']=='toxicchat' else any(c in r['cats'] for c in keys) for r in rows])
    error=np.abs(im-fm);boundary=np.abs(fm)<=error
    def summarize(mask):
        n=int(mask.sum());w=weights[mask]
        return {'n':n,'agreement':float((flags[mask]==(fm[mask]>0)).mean()) if n else None,
                'agreement_weighted':float(np.sum(w*(flags[mask]==(fm[mask]>0)))/w.sum()) if n else None,
                'float':metric(truth[mask],fm[mask]>0,w),'integer':metric(truth[mask],flags[mask],w)}
    return {'n':len(rows),'head':head,'refused':int(refused.sum()),'zero_refusals':not bool(refused.any()),
        'diagnostic_all':summarize(np.ones(len(rows),dtype=bool)),'accepted_only':summarize(~refused),
        'truth_scope':'broad toxicity proxy, not category ground truth' if rows[0]['dataset']=='toxicchat' else 'category labels, missing labels count as zero',
        'absolute_margin_error_quantiles':{str(q):float(np.quantile(error,q)) for q in (0,.5,.9,.95,.99,1)},
        'margin_within_integer_error':int(boundary.sum()),
        'boundary_or_disagreement_items':[{'id':r['id'],'float_margin':float(fm[i]),'integer_margin':float(im[i]),
            'absolute_error':float(error[i]),'within_error':bool(boundary[i]),'disagrees':bool(flags[i]!=(fm[i]>0)),
            'refused':bool(refused[i])} for i,r in enumerate(rows) if boundary[i] or flags[i]!=(fm[i]>0)],
        'diagnostic_note':'All-item metrics include diagnostic clamps for refused rows; only zero-refusal results meet the refusal criterion.'}


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--run',type=Path,required=True);args=parser.parse_args()
    complete=json.loads((args.run/'complete.json').read_text())
    if sha(args.run/'verdicts.json')!=complete['verdicts_sha256'] or sha(args.run/'run.json')!=complete['run_sha256']:
        raise ValueError('evaluation result provenance changed')
    data=json.loads((args.run/'verdicts.json').read_text());groups={};sources={};out={}
    for row in data['rows']:groups.setdefault((row['dataset'],row['template']),[]).append(row)
    for (dataset,template),rows in groups.items():
        tail='_le168_strat300' if dataset=='openai_mod' else ''
        path=PREP/'bench'/f'{dataset}_{template}{tail}.jsonl'
        reference=[json.loads(line) for line in path.read_text().splitlines()]
        expected=612 if dataset=='openai_mod' else 200
        float_rows={r['id']:r for r in reference};ids={r['id'] for r in rows}
        if len(reference)!=len(float_rows) or len(ids)!=len(rows):raise ValueError('duplicate integer or float rows')
        if any(r['template']!=template or r['bf16_emul'] for r in reference):raise ValueError('wrong float reference')
        if not ids.issubset(float_rows):raise ValueError('missing paired float reference')
        sources[str(path)]=sha(path)
        out[f'{dataset}/{template}']={'full_A1_set':len(rows)==expected and ids==set(float_rows),
            'heads':{head:paired(rows,float_rows,head) for head in ('refusal_free','calibrated')},
            'lengths':{'max_T':max(r['T'] for r in rows),'above_native_T256':sum(r['T']>256 for r in rows)}}
    result={'schema':'zk60-shieldstral-verdict-fidelity/1','sets':out,'float_source_sha256':sources,
            'integer_source_sha256':complete['verdicts_sha256'],
            'analysis_source_sha256':sha(__file__),
            'all_12_A1_sets_complete':len(out)==12 and all(g['full_A1_set'] for g in out.values()),
            'scope':'paired numerical fidelity, no native proof or privacy acceptance; subset results are explicitly marked'}
    atomic_json(args.run/'fidelity.json',result)
    print(json.dumps({'sets':len(out),'all_12_A1_sets_complete':result['all_12_A1_sets_complete'],
                      'report':str(args.run/'fidelity.json')}))


if __name__=='__main__':main()
