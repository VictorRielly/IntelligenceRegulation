"""Guarded S2 numerical verdict evaluation, resumable between small item groups.

Exact prompt lengths, no padding or truncation. All attention pairs are range
checked by rx_block. Overflow rows continue only as explicit diagnostic clamps;
they never count as accepted. First use a small --limit smoke before --all.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import time
import numpy as np
import calibration_port as P
from collect_stats import sha,atomic_json
from evaluation_export import EvaluationExport
from shieldstral_geometry import D,LAYERS,rope_tables
from shieldstral_weights import read_exact
from signed_word_domain import S2RecPos,DOMAIN

HERE=Path(__file__).resolve().parent


def read_journal(path):
    if not path.exists():return []
    raw=path.read_bytes();end=raw.rfind(b'\n')+1
    if end<len(raw):
        with path.open('r+b') as stream:stream.truncate(end)
    return [json.loads(line) for line in raw[:end].splitlines()]


def segment_digest(fd,offset,size):
    h=hashlib.sha256()
    for at in range(0,size,1<<20):h.update(read_exact(fd,min(1<<20,size-at),offset+at))
    return h.hexdigest()


def flush_group(stream,journal,start,end,begin,finish,diagnostics):
    stream.flush();os.fsync(stream.fileno())
    row={'first_item':start,'end_item':end,'byte_start':begin,'byte_end':finish,
         'sha256':segment_digest(stream.fileno(),begin,finish-begin),'diagnostics':diagnostics}
    with journal.open('a') as output:
        output.write(json.dumps(row,sort_keys=True)+'\n');output.flush();os.fsync(output.fileno())


def row_diagnostics(rec):
    return {'refused':rec.first[0] is not None,'first_site':rec.first[0],
            'violations':{key:dict(value) for key,value in rec.sites.items() if value['violations']}}


def execute_layer(stage,source,rows,offsets,ids,model,embedding,deadline):
    """Initial embedding stage uses model=None; later stages read int16 residuals."""
    stage.mkdir(exist_ok=True);journal=stage/'journal.jsonl';target=stage/'residual.bin';ready=stage/'ready.json'
    if ready.exists():
        saved=json.loads(ready.read_text())
        if sha(target)!=saved['residual_sha256'] or sha(journal)!=saved['journal_sha256']:
            raise ValueError('completed numerical checkpoint changed')
        return True
    temporary=stage/'residual.partial';entries=read_journal(journal)
    if entries and not temporary.exists():
        # Recover a crash after the final rename but before ready.json.
        if target.exists():os.rename(target,temporary)
        else:raise ValueError('journal exists without numerical output')
    src=os.open(source,os.O_RDONLY) if source is not None else None
    emb=os.open(embedding,os.O_RDONLY) if model is None else None
    try:
        with temporary.open('r+b' if temporary.exists() else 'w+b') as output:
            next_item=0;byte_end=0
            for entry in entries:
                if entry['first_item']!=next_item or entry['byte_start']!=byte_end:
                    raise ValueError('noncontiguous evaluation journal')
                count=entry['byte_end']-entry['byte_start']
                if segment_digest(output.fileno(),byte_end,count)!=entry['sha256']:raise ValueError('partial output changed')
                next_item=entry['end_item'];byte_end=entry['byte_end']
            expected_bytes=int(offsets[next_item])*D*2
            if byte_end!=expected_bytes:raise ValueError('journal token offsets differ')
            output.truncate(byte_end);output.seek(byte_end)
            first=next_item;begin=byte_end;diagnostics=[];ropes={}
            for index in range(next_item,len(rows)):
                if time.time()>deadline:
                    if index>first:flush_group(output,journal,first,index,begin,output.tell(),diagnostics)
                    return False
                start,stop=map(int,offsets[index:index+2]);tokens=stop-start
                if model is None:
                    token_ids=ids[start:stop]
                    values=np.empty((tokens,D),dtype='<i2')
                    for n,token in enumerate(token_ids):
                        values[n]=np.frombuffer(read_exact(emb,D*2,int(token)*D*2),dtype='<i2')
                    diag={'refused':False,'first_site':None,'violations':{}}
                else:
                    raw=read_exact(src,(stop-start)*D*2,start*D*2)
                    x=np.frombuffer(raw,dtype='<i2').reshape(1,tokens,D).astype(np.float64)
                    if tokens not in ropes:ropes[tokens]=tuple(t.astype(np.float64) for t in rope_tables(tokens,int(model.c['f_ro'])))
                    model.rope_int=ropes[tokens]
                    rec=S2RecPos(1)
                    values=P.fl.rx_block(x,model,frozenset(P.fl.SITES),rec)[0]
                    if not np.isfinite(values).all() or not np.array_equal(values,np.floor(values)) or np.any(values<-32768) or np.any(values>32767):
                        raise ValueError('diagnostic residual is not representable as int16')
                    values=values.astype('<i2');diag=row_diagnostics(rec)
                output.write(values.tobytes());diagnostics.append({'item':index,**diag})
                if index+1-first==32 or index+1==len(rows):
                    flush_group(output,journal,first,index+1,begin,output.tell(),diagnostics)
                    first=index+1;begin=output.tell();diagnostics=[]
        os.replace(temporary,target)
        atomic_json(ready,{'items':len(rows),'residual_sha256':sha(target),'journal_sha256':sha(journal)})
        return True
    finally:
        if src is not None:os.close(src)
        if emb is not None:os.close(emb)


def score_final(root,rows,offsets,token_io):
    table=json.loads((token_io/'classifier.json').read_text());norm=table['final_norm']
    margin=np.fromfile(token_io/'margin_int16.bin',dtype='<i2').astype(np.int64)
    if margin.shape!=(D,) or sha(token_io/'margin_int16.bin')!=table['margin_vector']['sha256']:
        raise ValueError('classifier margin differs')
    violations=[[] for _ in rows]
    for layer in range(LAYERS):
        for entry in read_journal(root/f'layer_{layer:02d}/journal.jsonl'):
            for diagnostic in entry['diagnostics']:
                if diagnostic['refused']:violations[diagnostic['item']].append({'layer':layer,**diagnostic})
    fd=os.open(root/f'layer_{LAYERS-1:02d}/residual.bin',os.O_RDONLY)
    output=[]
    try:
        for index,row in enumerate(rows):
            at=(int(offsets[index+1])-1)*D*2
            x=np.frombuffer(read_exact(fd,D*2,at),dtype='<i2').astype(np.int64).reshape(1,1,D)
            scores={}
            for choice,cn in (('refusal_free',norm['cn']),('calibrated',table['final_norm_candidates']['cn_calibrated'])):
                rec=P.tc.Rec(1)
                y,_=P.tc.i_norm(x,np.full(D,norm['g0'],dtype=np.int8),cn,norm['tn'],norm['ceps'],32,rec,'final_norm',0,True)
                delta=int(y.reshape(D)@margin)
                scale=float(P.b3.norm_K(cn,norm['tn'])/norm['g0']*table['margin_vector']['scale'])
                scores[choice]={'margin_int':delta,'margin_real':delta*scale,'flagged':delta>table['threshold_c'],
                                'head_refused':rec.first[0] is not None,'head_diagnostics':row_diagnostics(rec)}
            output.append({**row,'stack_refused':bool(violations[index]),'stack_diagnostics':violations[index],'heads':scores})
    finally:os.close(fd)
    atomic_json(root/'verdicts.json',{'schema':'zk60-shieldstral-s2-verdicts/1','rows':output,
        'scope':'numerical evaluator; refused values are clamped only to diagnose; no native proof or privacy acceptance'})
    return output


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--export',type=Path,default=HERE/'s2_evaluation_t256')
    parser.add_argument('--input',type=Path,default=HERE/'evaluation_inputs');parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--token-io',type=Path,help='separate R12b public table directory; original base remains immutable')
    parser.add_argument('--layer25-fix',type=Path,help='explicit numerical calibration candidate, not a native profile')
    parser.add_argument('--dataset',choices=['toxicchat','openai_mod']);parser.add_argument('--template')
    selection=parser.add_mutually_exclusive_group();selection.add_argument('--limit',type=int,default=8);selection.add_argument('--all',action='store_true')
    parser.add_argument('--max-minutes',type=float,default=25);args=parser.parse_args()
    data=json.loads((args.input/'input.json').read_text())
    for name,key in (('ids.npy','ids_sha256'),('offsets.npy','offsets_sha256')):
        if sha(args.input/name)!=data[key]:raise ValueError('evaluation inputs changed')
    original_ids=np.load(args.input/'ids.npy',allow_pickle=False);original_offsets=np.load(args.input/'offsets.npy',allow_pickle=False)
    indexes=[i for i,r in enumerate(data['rows']) if (not args.dataset or r['dataset']==args.dataset) and (not args.template or r['template']==args.template)]
    if not args.all:
        if args.limit<=0:raise ValueError('positive smoke limit required')
        indexes=indexes[:args.limit]
    if not indexes:raise ValueError('empty evaluation selection')
    rows=[data['rows'][i] for i in indexes]
    lengths=np.array([r['T'] for r in rows]);offsets=np.concatenate(([0],lengths.cumsum()))
    ids=np.concatenate([original_ids[original_offsets[i]:original_offsets[i+1]] for i in indexes])
    export=EvaluationExport(args.export);token_io=args.token_io or export.base/'token_io'
    token_done=json.loads((token_io/'complete.json').read_text())
    for name,digest in token_done['files'].items():
        if sha(token_io/name)!=digest:raise ValueError('tied token tables changed')
    if 'profile_sha256' in token_done:
        if sha(token_io.parent/'profile.json')!=token_done['profile_sha256']:
            raise ValueError('public table profile changed')
        profile=json.loads((token_io.parent/'profile.json').read_text())
        table=json.loads((token_io/'classifier.json').read_text())
        if table['final_norm']!=profile['token_io_parameters']['classifier_final_norm'] or table['bos']!=profile['token_io_parameters']['bos']:
            raise ValueError('classifier constants differ from bound profile')
    amendment=None
    if args.layer25_fix:
        from amended_evaluator import candidate_pin,apply_candidate
        amendment=candidate_pin(args.layer25_fix)
    plan={'schema':'zk60-shieldstral-eval-run/1','input_sha256':sha(args.input/'input.json'),
          'evaluation_export_sha256':sha(args.export/'complete.json'),'token_io_sha256':sha(token_io/'complete.json'),
          'tool_sha256':sha(__file__),'indexes':indexes,'items':len(rows),'tokens':int(offsets[-1]),
          'word_domain_amendment':DOMAIN,'word_domain_source_sha256':sha(HERE/'signed_word_domain.py'),
          'layer25_calibration_candidate':amendment,
          'input_scope':data.get('scope'),
          'scope':'smoke subset' if not args.all else ('full calibration replay' if all(r['dataset']=='calibration' for r in rows) else 'selected full A1 item sets')}
    args.out.mkdir(parents=True,exist_ok=True)
    if (args.out/'run.json').exists():
        if json.loads((args.out/'run.json').read_text())!=plan:raise ValueError('evaluation resume plan changed')
    else:atomic_json(args.out/'run.json',plan)
    deadline=time.time()+args.max_minutes*60
    if not execute_layer(args.out/'input',None,rows,offsets,ids,None,token_io/'embedding_int16.bin',deadline):return 3
    source=args.out/'input/residual.bin'
    for layer in range(LAYERS):
        stage=args.out/f'layer_{layer:02d}'
        model=None if (stage/'ready.json').exists() else export.layer(layer,export.profile['T'])
        if model is not None and layer==25 and args.layer25_fix:
            model=apply_candidate(model,args.layer25_fix)
        if not execute_layer(stage,source,rows,offsets,ids,model,None,deadline):return 3
        source=stage/'residual.bin';del model
        print(json.dumps({'layer':layer,'items':len(rows),'status':'complete'}),flush=True)
    result=score_final(args.out,rows,offsets,token_io)
    atomic_json(args.out/'complete.json',{'items':len(rows),'verdicts_sha256':sha(args.out/'verdicts.json'),
        'run_sha256':sha(args.out/'run.json'),'stack_refused':sum(r['stack_refused'] for r in result)})
    return 0


if __name__=='__main__':raise SystemExit(main())
