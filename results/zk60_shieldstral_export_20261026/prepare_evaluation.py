"""Pin A1's exact 200/612 items under all six policies, without truncation.

Ragged full-prompt IDs preserve the original full-item comparison. Native
T128/T256 coverage is counted separately; longer prompts are not silently
dropped or presented as supported native classifier proofs.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

HERE=Path(__file__).resolve().parent
PREP=HERE.parent/'zk60_shieldstral_prep_20261021'
sys.path.insert(0,str(PREP/'tools'))
import shieldstral_common as C
C.setup_paths()
import numpy as np
from bench_run import load_set


def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--out',type=Path,default=HERE/'evaluation_inputs')
    args=parser.parse_args()
    if args.out.exists():raise ValueError('evaluation input directory already exists')
    flat=[];offsets=[0];rows=[];sources={};coverage={};policies={}
    for dataset,n in (('toxicchat',200),('openai_mod',612)):
        population={r['id']:r for r in load_set(dataset)};expected_ids=None
        for category in ('sexual','violence','hate'):
            suffix='' if dataset=='toxicchat' else '_le168_strat300'
            path=PREP/'bench'/f'{dataset}_cat_{category}{suffix}.jsonl'
            reference=[json.loads(line) for line in path.read_text().splitlines()]
            identifiers={r['id'] for r in reference}
            if len(reference)!=n or len(identifiers)!=n:raise ValueError('A1 strict reference is incomplete or duplicated')
            if expected_ids is not None and identifiers!=expected_ids:raise ValueError('A1 categories use different item sets')
            expected_ids=identifiers;sources[str(path)]=digest(path)
            for strictness in ('cat','mod'):
                template=f'{strictness}_{category}';counts={k:0 for k in ('total','le128','le256','gt256','gt512')};maximum=0
                for r in reference:
                    source=population[r['id']];prefix,content,suffix_ids=C.ids_split(template,source['content'])
                    ids=C.ids_full(template,source['content'])
                    if ids!=prefix+content+suffix_ids:raise ValueError('template split differs from whole tokenization')
                    if len(content)!=r['n_content_tokens']:raise ValueError('A1 content tokenization changed')
                    if strictness=='cat' and len(ids)!=r['T']:raise ValueError('A1 full prompt length changed')
                    prior=policies.setdefault(template,{'template':C.TEMPLATES[template],'prefix':prefix,'suffix':suffix_ids})
                    if prior['prefix']!=prefix or prior['suffix']!=suffix_ids:raise ValueError('policy template varies by item')
                    rows.append({'dataset':dataset,'template':template,'id':r['id'],'content_tokens':len(content),'T':len(ids),
                        'label':r['label'],'cats':r.get('cats',[]),'known':r.get('known',[]),'weight':r.get('weight',1.),
                        'native_T256_length_covered':len(ids)<=256})
                    flat.extend(ids);offsets.append(len(flat));counts['total']+=1
                    for key,condition in (('le128',len(ids)<=128),('le256',len(ids)<=256),('gt256',len(ids)>256),('gt512',len(ids)>512)):
                        counts[key]+=int(condition)
                    maximum=max(maximum,len(ids))
                coverage[f'{dataset}/{template}']={**counts,'max_T':maximum}
    args.out.mkdir()
    np.save(args.out/'ids.npy',np.array(flat,dtype='<i8'))
    np.save(args.out/'offsets.npy',np.array(offsets,dtype='<i8'))
    plan={'schema':'zk60-shieldstral-evaluation-input/1','items':len(rows),'tokens':len(flat),'rows':rows,'coverage':coverage,
          'policies':policies,'source_reference_sha256':sources,'data_source_sha256':{
              C.TOXICCHAT_CSV:digest(C.TOXICCHAT_CSV),C.OPENAI_MOD_JSONL_GZ:digest(C.OPENAI_MOD_JSONL_GZ)},
          'tool_sha256':digest(__file__),'tokenizer_sha256':digest(Path(C.MODEL_DIR)/'tokenizer.json'),
          'ids_sha256':digest(args.out/'ids.npy'),'offsets_sha256':digest(args.out/'offsets.npy'),
          'scope':'full-item numerical fidelity inputs; no truncation; length coverage is not a native proof acceptance'}
    (args.out/'input.json').write_text(json.dumps(plan,indent=2)+'\n')
    print(json.dumps({k:plan[k] for k in ('items','tokens','coverage','scope')},indent=2))


if __name__=='__main__':main()
