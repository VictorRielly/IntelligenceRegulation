"""Deterministic calibration prompts, disjoint from A1's ToxicChat-200.

Use other human-annotated ToxicChat test rows only as CALIBRATION, never as a
new evaluation set. Six fixed policies share each chosen document. Labels are
used only to balance selection. Full prompts fit T; no document is truncated.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import sys
import numpy as np

HERE = Path(__file__).resolve().parent
PREP = HERE.parent/'zk60_shieldstral_prep_20261021'
sys.path.insert(0,str(PREP/'tools'))
import shieldstral_common as C
C.setup_paths()


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--T',type=int,choices=[128,256],default=256)
    ap.add_argument('--documents',type=int,default=32)
    ap.add_argument('--out',type=Path,required=True)
    a=ap.parse_args()
    if a.out.exists(): raise SystemExit('refusing to overwrite calibration data')
    if a.documents <= 0 or a.documents % 2: raise SystemExit('documents must be positive and even')
    heldout=set()
    for name in ('hate','sexual','violence'):
        rows=[json.loads(line) for line in (PREP/'bench'/f'toxicchat_cat_{name}.jsonl').read_text().splitlines()]
        ids={str(r['id']) for r in rows}
        if len(ids)!=200 or len(rows)!=200: raise ValueError('A1 ToxicChat-200 IDs incomplete or duplicated')
        if heldout and heldout != ids: raise ValueError('A1 categories use different held-out IDs')
        heldout=ids
    templates=[p+'_'+c for p in ('cat','mod') for c in ('hate','sexual','violence')]
    with open(C.TOXICCHAT_CSV,newline='') as f:
        rows=[r for r in csv.DictReader(f) if r['human_annotation'].lower()=='true' and r['conv_id'] not in heldout]
    rng=np.random.default_rng(20261026)
    candidates=[rows[i] for i in rng.permutation(len(rows))]
    groups={0:[],1:[]}
    for row in candidates:
        label=int(row['toxicity'])
        if len(groups[label]) >= a.documents//2: continue
        seqs=[C.ids_full(t,row['user_input']) for t in templates]
        if max(map(len,seqs)) > a.T: continue
        groups[label].append((row['conv_id'],seqs))
        if all(len(v)==a.documents//2 for v in groups.values()): break
    if any(len(v)!=a.documents//2 for v in groups.values()): raise ValueError('not enough eligible disjoint documents')
    seqs=[]; meta=[]; lengths=[]
    pad=C.hf_tokenizer().token_to_id('</s>')
    for label,group in groups.items():
        for ident,values in group:
            for template,ids in zip(templates,values):
                meta.append({'id':ident,'template':template,'selection_label':label,'length':len(ids)})
                lengths.append(len(ids)); seqs.append(ids+[pad]*(a.T-len(ids)))
    ids=np.asarray(seqs,dtype='<i8')
    info={'schema':'zk60-shieldstral-calibration-input/1','T':a.T,'documents':a.documents,
          'sequences':len(ids),'seed':20261026,'ids_sha256':hashlib.sha256(ids.tobytes()).hexdigest(),
          'heldout_ids_sha256':hashlib.sha256('\n'.join(sorted(heldout)).encode()).hexdigest(),
          'dataset':C.TOXICCHAT_CSV,'dataset_sha256':hashlib.sha256(Path(C.TOXICCHAT_CSV).read_bytes()).hexdigest(),
          'padding':'right EOS; all rows included in range statistics; no truncation',
          'scope':'calibration only; disjoint from A1 ToxicChat-200; no OpenAI benchmark examples used',
          'metadata':meta}
    a.out.mkdir(parents=True)
    np.save(a.out/'ids.npy',ids)
    np.save(a.out/'lengths.npy',np.asarray(lengths,dtype='<i8'))
    (a.out/'input.json').write_text(json.dumps(info,indent=2)+'\n')
    print(json.dumps({k:v for k,v in info.items() if k!='metadata'}))


if __name__=='__main__': main()
