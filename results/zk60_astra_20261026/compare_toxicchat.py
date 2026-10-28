"""Completed ToxicChat strict/moderate pairs; broad-toxicity proxy only."""
import hashlib
import json
from pathlib import Path
import numpy as np

HERE=Path(__file__).resolve().parent;PREP=HERE.parent/'zk60_shieldstral_prep_20261021'

def metrics(y,p):
    tp=int((y&p).sum());fp=int((~y&p).sum());fn=int((y&~p).sum())
    return {'precision':tp/(tp+fp) if tp+fp else None,'recall':tp/(tp+fn),
            'f1':2*tp/(2*tp+fp+fn),'tp':tp,'fp':fp,'fn':fn,'flag_count':int(p.sum())}

def main():
    out={'scope':'MEASURED completed ToxicChat200 paired strict/moderate results. Broad toxicity is a proxy, not category ground truth. No policy recommendation before complete OpenAI category comparison.',
         'source_sha256':{},'categories':{}}
    base=None;union={'strict':np.zeros(200,bool),'moderate':np.zeros(200,bool)}
    for category in ('sexual','violence','hate'):
        pair={}
        for name,prefix in (('strict','cat'),('moderate','mod')):
            path=PREP/'bench'/f'toxicchat_{prefix}_{category}.jsonl';raw=path.read_bytes()
            data=[json.loads(line) for line in raw.splitlines()];indexed={r['id']:r for r in data}
            assert len(data)==len(indexed)==200
            assert all(r['template']==prefix+'_'+category and not r['bf16_emul'] for r in data)
            ids=sorted(indexed)
            if base is None:base=ids
            assert ids==base
            pair[name]=[indexed[i] for i in ids]
            out['source_sha256'][str(path.relative_to(HERE.parent))]=hashlib.sha256(raw).hexdigest()
        assert all(a['label']==b['label'] and a['n_content_tokens']==b['n_content_tokens'] for a,b in zip(pair['strict'],pair['moderate']))
        y=np.array([r['label']==1 for r in pair['strict']]);flags={};row={}
        for name,data in pair.items():
            margin=np.array([r['margin'] for r in data]);flags[name]=margin>0;union[name]|=flags[name]
            row[name]={**metrics(y,flags[name]),'median_abs_margin':float(np.median(np.abs(margin))),
                       'abs_margin_below_1':int((np.abs(margin)<1).sum())}
        row['strict_yes_moderate_no']=[base[i] for i in np.flatnonzero(flags['strict']&~flags['moderate'])]
        row['strict_no_moderate_yes']=[base[i] for i in np.flatnonzero(~flags['strict']&flags['moderate'])]
        out['categories'][category]=row
    out['union_vs_toxicity']={name:metrics(y,flags) for name,flags in union.items()}
    (HERE/'toxicchat_policy_comparison.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps({'categories':out['categories'],'union':out['union_vs_toxicity']}))

if __name__=='__main__':main()
