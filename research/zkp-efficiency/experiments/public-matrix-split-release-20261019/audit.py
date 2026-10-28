"""Independent persisted-artifact oracle. Does not import the experiment.

Checks native-compatible public word/table SHA256s; block/wire are explicitly
synthetic surrogates. Rebuilds geometry, metadata and all refusal expectations.
"""
from pathlib import Path
import hashlib
import json
import os
import resource
import signal
import struct
import time

HERE=Path(__file__).resolve().parent
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
t0=time.perf_counter();checks=0;corruptions=0


def check(ok):
    global checks
    assert ok
    checks+=1


def digest(b):return hashlib.sha256(b).hexdigest()


def pack(v,width):return struct.pack('<'+{1:'b',2:'h',8:'q'}[width]*len(v),*v)


cases=json.loads((HERE/'input-cases.json').read_text())
artifacts=json.loads((HERE/'fixtures.json').read_text())
for artifact in artifacts:
    case=artifact['case'];result=artifact['result'];s=case['shape'];full=artifact['full']
    check(case==cases[case['metadata']['index']])
    d=s['qh']*s['hd'];dp=s['hp']*s['hd'];f=s['f'];fp=2**((f-1).bit_length());k=s['kv']*s['hd']
    qslots=[(g*(s['hp']//s['kv'])+j)*s['hd']+lane
        for g in range(s['kv']) for j in range(s['qh']//s['kv']) for lane in range(s['hd'])]
    dims={'wq':(d,d,dp,dp,qslots,list(range(d))),
        'wk':(k,d,k,dp,list(range(k)),list(range(d))),
        'wv':(k,d,k,dp,list(range(k)),list(range(d))),
        'wo':(d,d,dp,dp,list(range(d)),qslots),
        'gamma_a':(1,d,1,dp,[0],list(range(d))),
        'gamma_m':(1,d,1,dp,[0],list(range(d))),
        'wg':(d,f,dp,fp,list(range(d)),list(range(f))),
        'wu':(d,f,dp,fp,list(range(d)),list(range(f))),
        'wd':(f,d,fp,dp,list(range(f)),list(range(d)))}
    expected={};words=[];serial=b''
    for name,(nr,nc,pr,pc,rs,cs) in dims.items():
        raw=bytes.fromhex(case['arrays'][name]['hex'])
        # Destination-oriented independent reference, including every pad.
        ri={v:i for i,v in enumerate(rs)};ci={v:i for i,v in enumerate(cs)}
        out=[]
        for r in range(pr):
            for c in range(pc):
                out.append(struct.unpack('b',raw[ri[r]*nc+ci[c]:ri[r]*nc+ci[c]+1])[0] if r in ri and c in ci else 0)
        expected[name]=out
        check(out==result['block'][name]);encoded=pack(out,1);words.append(digest(encoded))
        serial+=struct.pack('<Q',len(out))+encoded
        bad=bytearray(encoded);bad[0]^=1;check(digest(bad)!=words[-1]);corruptions+=1
    tables={}
    for name,width in [('exp',8),('act',2)]:
        raw=bytes.fromhex(case['arrays'][name]['hex'])
        tables[name]=list(struct.unpack('<'+('q' if width==8 else 'h')*256,raw))
    n=s['t']*(s['hd']//2);tables.update(cos=[65536]*n,sin=[0]*n)
    note='absent'
    if 'cos' in case['arrays'] and 'sin' in case['arrays']:
        parsed={name:list(struct.unpack('<'+'q'*n,bytes.fromhex(case['arrays'][name]['hex']))) for name in ['cos','sin']}
        if parsed=={name:tables[name] for name in ['cos','sin']}:note='equal'
        else:
            check(case['opt_in']);note='opted_in';tables.update(parsed)
    for name,width in [('cos',8),('sin',8),('exp',8),('act',2)]:
        check(result['block'][name]==tables[name]);serial+=struct.pack('<Q',len(tables[name]))+pack(tables[name],width)
    check(result['block_hex']==serial.hex())
    check(result['block_sha256_surrogate']==digest(serial));check(result['rope_note']==note)
    th=[digest(pack(tables['cos']+tables['sin'],8)),digest(pack(tables['exp'],8)),digest(pack(tables['act'],2))]
    m=case['metadata']
    rec=dict(index=m['index'],block_digest=digest(serial) if full else '00'*32,
        word_sha256=words if full else ['00'*32]*9,table_sha256=th if full else ['00'*32]*3,
        source_tensors=sorted(m['source_tensors']) if full else [],manifest_sha256=m['manifest'],
        silu_member=m['silu'],exp_e_s=m['e_s'],own=m['own'])
    check(rec==result['record'])
    expected_record=json.dumps(rec,sort_keys=True,separators=(',',':')).encode()
    check(result['record_hex']==expected_record.hex())
    check(len(artifact['baseline_live_before_record'])==11)
    check(result['trace'][-1]==['before_record',[]])
    check(result['trace'][0][1]==sorted(case['arrays'].keys()-{'cos','sin'}))
    check(result['trace'][1:3]==[['after_padding',['act','exp']],['constructed',['act','exp']]])
    check(tuple(result['tail_copy_fields'])==(case['arrays']['wq']['sha'],case['arrays']['exp']['sha']))
    # Every record field participates in equality; corrupt each independently.
    for field in rec:
        bad=dict(rec);bad[field]=None if bad[field] is not None else 1
        check(json.dumps(bad,sort_keys=True,separators=(',',':')).encode()!=expected_record);corruptions+=1

# Independent expected first error for every persisted malformed/control path.
controls=json.loads((HERE/'control-results.json').read_text())
for row in controls:
    index=row['fixture'];label=row['label'];full=row['full']
    honest='rope_mismatch' if index%5==3 else 'accept'
    if label=='paired':want='manifest_type_shape:wq'
    elif label=='metadata':want='rope_mismatch' if honest!='accept' else 'source_tensors'
    elif label.startswith('generator:'):want=label.split(':')[1]+'_generator'
    else:
        name,kind=label.split(':')
        if kind in ['dtype','shape']:want='manifest_type_shape:'+name
        elif kind in ['short','long']:want='exact_length:'+name
        elif full:want='sha:'+name
        elif kind=='content' and name in ['exp','act']:want=name+'_generator'
        else:want=honest
    check(row['candidate']==row['baseline']==want)
check(len(controls)==6720)

# Independent dimension-derived allocation-free model; no prior ledger math used.
d=4096;f=14336;dp=4096;fp=16384;kv=1024;t=128;hd=128
raw=2*d*d+2*kv*d+2*d+3*d*f+256*8+256*2
pad=2*dp*dp+2*kv*dp+2*dp+3*dp*fp
rope=2*t*(hd//2)*8;small=256*10;pub=pad+rope+small
maps=max(16*fp+8*dp,16*dp+8*fp);support=8*fp
ledger=json.loads((HERE/'payload-ledger.json').read_text());check(ledger['raw11_bytes']==raw)
import re
native=(HERE/'native/hashline__src__private_block__trained_block.rs').read_text()
groups={}
for group in ['aw','fw']:
    expr=native.split('        let '+group+' = [',1)[1].split('];',1)[0]
    groups[group]=re.findall(r'&(\w+)\.i8s\(\)',expr)
check(groups=={'aw':['wq','wk','wv','wo','ga'],'fw':['gm','wg','wu','wd']})
sizes=dict(wq=d*d,wk=kv*d,wv=kv*d,wo=d*d,ga=d,gm=d,wg=d*f,wu=d*f,wd=d*f)
correction=ledger['temporary_scope_correction']
check(correction['fw_statement_temporary_bytes']==sum(sizes[n] for n in groups['fw']))
check(correction['aw_statement_temporary_bytes']==sum(sizes[n] for n in groups['aw']))
check(correction['delta_bytes']==sum(sizes[n] for n in groups['fw'])-max(sizes.values()))
for row in ledger['rows']:
    copied=row['constructor']=='borrowed_copy'
    p=raw+pad+maps+2*rope+small+(3*d*f+d if row['decode_mode']=='native_decode' else 0)
    c=raw+pad+2*rope+pub+small+support if copied else raw+pub+rope+small+support
    hash_scratch=(dp*fp if row['hash_workers']==1 else pad) if row['full'] else 0
    r=raw+pub+(pad+rope if copied else 0)+hash_scratch+rope+small
    b=[p,c,r];a=[p,c-(raw-small),r-raw];post=[p,c,r-raw]
    check(row['before_phase_bytes']==b and row['after_phase_bytes']==a)
    check(row['before_envelope_bytes']==max(b) and row['after_envelope_bytes']==max(a))
    check(row['saving_bytes']==max(b)-max(a))
    check(row['after_current_next_pins_bytes']==max(a)+(row['pins']+1)*pub)
    check(row['prior_postconstructor_envelope_bytes']==max(post))
    check(row['incremental_saving_bytes']==max(post)-max(a))
    # Falsify blanket subtraction from full-loader peak whenever another phase wins.
    if row['saving_bytes']<raw:check(row['after_envelope_bytes']!=row['before_envelope_bytes']-raw)

out=dict(status='PASS',checks=checks,accepted_path_cases=len(artifacts),independent_first_error_checks=len(controls),
    independent_corruptions=corruptions,wall_seconds=time.perf_counter()-t0,
    rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,affinity=sorted(os.sched_getaffinity(0)),nice=os.nice(0),
    scope='Independent synthetic reconstruction and accounting only; no native loader/proof execution')
(HERE/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,sort_keys=True))
