"""Synthetic loader lifecycle differential. No native code or foreign scripts run.

Only the explicit raw-release boundary differs in the two modeled loaders.
Reference placement in audit.py uses independent destination indexing.
"""
import copy
import hashlib
import json
import os
from pathlib import Path
import platform
import random
import resource
import signal
import time

HERE = Path(__file__).resolve().parent
SEED = 2026101988
NAMES = ['wq','wk','wv','wo','gamma_a','gamma_m','wg','wu','wd','exp','act']
MATRICES = NAMES[:9]
checks = 0


def check(value):
    global checks
    assert value
    checks += 1


def sha(data):
    return hashlib.sha256(data).hexdigest()


def enc(values, width):
    return b''.join(int(v).to_bytes(width, 'little', signed=True) for v in values)


def decode(raw, width):
    return [int.from_bytes(raw[i:i+width], 'little', signed=True) for i in range(0, len(raw), width)]


class Refusal(Exception):
    pass


class Raw:
    def __init__(self, name, raw, live):
        self.name, self.raw, self.live = name, raw, live
        self.released = False
        live.add(name)

    def read(self):
        if self.released:
            raise Refusal('use_after_release:' + self.name)
        return self.raw

    def release(self):
        assert not self.released
        self.live.remove(self.name)
        self.raw = None
        self.released = True


def make_case(fix, number):
    s = dict(fix['shape'])
    s['t'] = 3 + number % 3
    arrays = {}
    # Distinct synthetic bytes per matrix catch accidental reuse of another array.
    for j, m in enumerate(fix['matrices']):
        data = bytes((b + 17*j + number) % 256 for b in bytes.fromhex(m['raw_hex']))
        arrays[m['name']] = dict(dtype='i8', shape=m['dims'][:2], hex=data.hex(), sha=sha(data))
    tables = dict(exp=[512-2*k for k in range(256)], act=[(k-128)*4 for k in range(256)])
    for name, width in [('exp', 8), ('act', 2)]:
        raw = enc(tables[name], width)
        arrays[name] = dict(dtype='i'+str(width*8), shape=[256], hex=raw.hex(), sha=sha(raw))
    half = s['hd']//2
    rope = dict(cos=[65536]*(s['t']*half), sin=[0]*(s['t']*half))
    # absent, equal, opted-in mismatch, denied mismatch, and one-sided export.
    branch = number % 5
    if branch in [1,2,3]:
        for name in ['cos','sin']:
            v = list(rope[name])
            if branch in [2,3] and name == 'sin':
                v[-1] = 1
            raw = enc(v,8)
            arrays[name] = dict(dtype='i64',shape=[s['t'],half] if number%2 else [s['t']*half],hex=raw.hex(),sha=sha(raw))
    elif branch == 4:
        raw = enc(rope['cos'],8)
        arrays['cos'] = dict(dtype='i64',shape=[s['t'],half],hex=raw.hex(),sha=sha(raw))
    return dict(shape=s, arrays=arrays, opt_in=branch==2,
        metadata=dict(index=number,manifest=sha(('synthetic manifest '+str(number)).encode()),
            source_tensors=[['z',sha(b'z')],['a',sha(b'a')]],silu=[-3,-11],e_s=0,
            own=[None,17,None,None,None,None,None,None,None,None,None]))


def dims(s):
    d=s['qh']*s['hd']; k=s['kv']*s['hd']; dp=s['hp']*s['hd']; f=s['f']; fp=1<<(f-1).bit_length()
    return {'wq':(d,d,dp,dp,'q','i'),'wk':(k,d,k,dp,'i','i'),
        'wv':(k,d,k,dp,'i','i'),'wo':(d,d,dp,dp,'i','q'),
        'gamma_a':(1,d,1,dp,'i','i'),'gamma_m':(1,d,1,dp,'i','i'),
        'wg':(d,f,dp,fp,'i','i'),'wu':(d,f,dp,fp,'i','i'),'wd':(f,d,fp,dp,'i','i')}


def load(case, full, release, control=None):
    live=set(); raw={}; trace=[]; s=case['shape']; ds=dims(s)
    def read_checked(name, width, shapes):
        spec=case['arrays'][name]
        if spec['dtype'] != 'i'+str(width*8) or spec['shape'] not in shapes:
            raise Refusal('manifest_type_shape:'+name)
        data=bytes.fromhex(spec['hex'])
        n=width
        for size in spec['shape']: n*=size
        if len(data)!=n: raise Refusal('exact_length:'+name)
        if full and sha(data)!=spec['sha']: raise Refusal('sha:'+name)
        return Raw(name,data,live)
    # Native performs parallel reads but consumes their results in this order.
    # Sequential synthesis reproduces selected first error, not IO concurrency.
    for name in NAMES:
        width=8 if name=='exp' else 2 if name=='act' else 1
        shape=[256] if width>1 else list(ds[name][:2])
        raw[name]=read_checked(name,width,[shape])
    trace.append(['raw_loaded',sorted(live)])
    if decode(raw['exp'].read(),8)!=[512-2*k for k in range(256)]: raise Refusal('exp_generator')
    if decode(raw['act'].read(),2)!=[(k-128)*4 for k in range(256)]: raise Refusal('act_generator')
    h=s['hd']//2; cosine=[65536]*(s['t']*h); sine=[0]*(s['t']*h); note='absent'
    if 'cos' in case['arrays'] and 'sin' in case['arrays']:
        ca=read_checked('cos',8,[[s['t'],h],[s['t']*h]])
        sa=read_checked('sin',8,[[s['t'],h],[s['t']*h]])
        ec,es=decode(ca.read(),8),decode(sa.read(),8)
        ca.release(); sa.release()
        if (ec,es)==(cosine,sine): note='equal'
        elif case['opt_in']: cosine,sine,note=ec,es,'opted_in'
        else: raise Refusal('rope_mismatch')
    if control=='early_drop':
        for v in raw.values(): v.release()
    def axis(i, tag):
        if tag=='i': return i
        head,lane=divmod(i,s['hd']); group,within=divmod(head,s['qh']//s['kv'])
        return (group*(s['hp']//s['kv'])+within)*s['hd']+lane
    padded={}
    for name,(nr,nc,pr,pc,ra,ca) in ds.items():
        data=decode(raw[name].read(),1); out=[0]*(pr*pc)
        for row in range(nr):
            for col in range(nc): out[axis(row,ra)*pc+axis(col,ca)]=data[row*nc+col]
        padded[name]=out
    padded.update(cos=cosine,sin=sine,exp=decode(raw['exp'].read(),8),act=decode(raw['act'].read(),2))
    # Borrowed Rust constructors copy vector data into the returned public block.
    block={name:list(values) for name,values in padded.items()}
    trace.append(['constructed',sorted(live)])
    # The native tail reads two Copy SHA fields. Capture them before moving raw.
    tail_fields=(case['arrays']['wq']['sha'],case['arrays']['exp']['sha'])
    if release and control!='digests_only':
        for v in raw.values(): v.release()
    trace.append(['before_record',sorted(live)])
    meta=copy.deepcopy(case['metadata'])
    for name,digest in meta['source_tensors']:
        if not isinstance(name,str) or len(digest)!=64:
            raise Refusal('source_tensors')
        try: bytes.fromhex(digest)
        except ValueError: raise Refusal('source_tensors')
    serial=b''
    for name in MATRICES+['cos','sin','exp','act']:
        width=8 if name in ['cos','sin','exp'] else 2 if name=='act' else 1
        serial+=len(block[name]).to_bytes(8,'little')+enc(block[name],width)
    # Explicit SHA256 surrogate for native BLAKE3 BlockPublic::digest; no native claim.
    digest=sha(serial)
    record=dict(index=meta['index'],block_digest=digest if full else '00'*32,
        word_sha256=[sha(enc(block[n],1)) for n in MATRICES] if full else ['00'*32]*9,
        table_sha256=[sha(enc(block['cos']+block['sin'],8)),sha(enc(block['exp'],8)),sha(enc(block['act'],2))] if full else ['00'*32]*3,
        source_tensors=sorted(meta['source_tensors']) if full else [],manifest_sha256=meta['manifest'],
        silu_member=meta['silu'],exp_e_s=meta['e_s'],own=meta['own'])
    record_bytes=json.dumps(record,sort_keys=True,separators=(',',':')).encode()
    if not release or control=='digests_only':
        for v in raw.values(): v.release()
    check(not live)
    return dict(block=block,block_sha256_surrogate=digest,record=record,record_hex=record_bytes.hex(),
        block_hex=serial.hex(),trace=trace,rope_note=note,tail_copy_fields=tail_fields)


def verdict(case,full,release,control=None):
    try: return 'accept',load(case,full,release,control)
    except Refusal as e: return str(e),None


def accounting():
    prior=json.loads((HERE/'prior-direct-ledger.json').read_text())
    raw=218114560; rows=[]
    # Cross decode/move variants; arrays release only after constructors.
    for decode_mode in ['native_decode','prior_direct_decode']:
        for original in prior['rows']:
            for full in [True,False]:
                before=original.copy()
                if decode_mode=='native_decode': before['pad_phase_bytes']+=58720256
                # Reload has no LayerRecord hash scratch. Return phase remains.
                live_return=before['record_phase_bytes']-(67108864 if before['native_workers_accounted']==1 else 243277824)
                bph=[before['pad_phase_bytes'],before['constructor_phase_bytes'],before['record_phase_bytes'] if full else live_return]
                aph=[before['pad_phase_bytes'],before['constructor_phase_bytes'],bph[-1]-raw]
                bp,ap=max(bph),max(aph)
                resident=(before['pins']+1)*243411456
                rows.append(dict(decode_mode=decode_mode,constructor=before['mode'],hash_workers=before['native_workers_accounted'],
                    pins=before['pins'],full=full,before_phase_bytes=bph,after_phase_bytes=aph,
                    before_envelope_bytes=bp,after_envelope_bytes=ap,saving_bytes=bp-ap,
                    before_current_next_pins_bytes=resident+bp,after_current_next_pins_bytes=resident+ap,
                    after_gib=(resident+ap)/2**30,limiting_phase=['pad','constructor','record' if full else 'return'][aph.index(ap)]))
    return dict(raw11_bytes=raw,raw_mib=raw/2**20,rows=rows,
        scope='Conservative enumerated public payload envelopes, not actual RSS/VRAM/allocator/timing or complete peak. Release changes record/return phase only.',
        exclusions=prior['exclusions']+['additional evicted live leases','private witness/proof state retained by owner'])


def main():
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59)); signal.alarm(59)
    os.nice(19); os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    t0=time.perf_counter(); rng=random.Random(SEED)
    fixtures=json.loads((HERE/'input-fixtures.json').read_text())
    artifacts=[]; mutations=0; refused=0; branches=set(); neg={}; cases=[]; controls=[]
    for number,fix in enumerate(fixtures):
        case=make_case(fix,number)
        cases.append(case)
        for full in [True,False]:
            b,base=verdict(case,full,False); c,cand=verdict(case,full,True)
            check(b==c)
            if b=='accept':
                branches.add(cand['rope_note'])
                for field in ['block','block_hex','block_sha256_surrogate','record','record_hex','rope_note','tail_copy_fields']:
                    check(base[field]==cand[field])
                check(len(base['trace'][-1][1])==11 and cand['trace'][-1][1]==[])
                artifacts.append(dict(case=case,full=full,result=cand,baseline_live_before_record=base['trace'][-1][1]))
                early,_=verdict(case,full,True,'early_drop');check(early=='use_after_release:wq')
                _,fake=verdict(case,full,True,'digests_only');check(len(fake['trace'][-1][1])==11)
                neg['early_drop_refused']=neg.get('early_drop_refused',0)+1
                neg['digest_copy_does_not_release']=neg.get('digest_copy_does_not_release',0)+1
            else: refused+=1
        bads=[]
        for name in NAMES:
            for kind in ['dtype','shape','short','long','sha','content']:
                bad=copy.deepcopy(case); a=bad['arrays'][name]
                if kind=='dtype': a['dtype']='i64' if a['dtype']!='i64' else 'i8'
                if kind=='shape': a['shape']=[999]
                if kind=='short': a['hex']=a['hex'][:-2]
                if kind=='long': a['hex']+='ff'
                if kind=='sha': a['sha']='00'*32
                if kind=='content':
                    v=bytearray.fromhex(a['hex']);v[rng.randrange(len(v))]^=1;a['hex']=v.hex()
                bads.append((name+':'+kind,bad))
        for name in ['exp','act']:
            bad=copy.deepcopy(case);a=bad['arrays'][name];v=bytearray.fromhex(a['hex']);v[0]^=1;a['hex']=v.hex();a['sha']=sha(v)
            bads.append(('generator:'+name,bad))
        bad=copy.deepcopy(case);bad['metadata']['source_tensors'][0][1]='not-a-digest';bads.append(('metadata',bad))
        # Paired faults ensure earlier array refusal wins over a later table fault.
        bad=copy.deepcopy(case);bad['arrays']['wq']['dtype']='i64';bad['arrays']['act']['hex']='00';bads.append(('paired',bad))
        for label,bad in bads:
            for full in [True,False]:
                b,bo=verdict(bad,full,False);c,co=verdict(bad,full,True);check(b==c)
                controls.append(dict(fixture=number,label=label,full=full,baseline=b,candidate=c))
                if bo is not None:
                    check(bo['block_hex']==co['block_hex'] and bo['record_hex']==co['record_hex'])
                mutations+=1
        # Reload content changes must be caught by the EXISTING caller digest gate.
        if number%5!=3:
            seal=load(case,True,True)
            changed=copy.deepcopy(case);a=changed['arrays']['wq'];v=bytearray.fromhex(a['hex']);v[0]^=1;a['hex']=v.hex()
            for release in [False,True]:
                reload=load(changed,False,release)
                check(reload['block_sha256_surrogate']!=seal['block_sha256_surrogate'])
                neg['reload_digest_mismatch']=neg.get('reload_digest_mismatch',0)+1
            check(verdict(changed,True,True)[0]=='sha:wq')
    ledger=accounting()
    check(len(ledger['rows'])==32)
    for row in ledger['rows']:
        check(row['saving_bytes']>=0)
        if not row['full']:check(row['saving_bytes']==0)
    result=dict(status='PASS',run_id='20261019T201854Z-ec298e23',seed=SEED,checks=checks,fixtures=len(fixtures),
        accepted_path_cases=len(artifacts),honest_refusals=refused,mutation_path_cases=mutations,negative_controls=neg,
        rope_branches=sorted(branches),wall_seconds=time.perf_counter()-t0,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        affinity=sorted(os.sched_getaffinity(0)),threads=1,nice=os.nice(0),python=platform.python_version(),platform=platform.platform(),
        cpu=next(l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),
        measured_scope='Synthetic public loader lifetime, integer bytes/SHA256 word records and modeled refusals. SHA256 block surrogate and JSON are NOT native BLAKE3/record wire/proof equivalence.',
        limits='one nice19 CPU,59s wall/CPU,512MiB AS,estimated128MiB; no builds/GPU/proofs')
    for name,val in [('fixtures.json',artifacts),('input-cases.json',cases),('control-results.json',controls),('payload-ledger.json',ledger),('result.json',result)]:
        (HERE/name).write_text(json.dumps(val,indent=2)+'\n')
    print(json.dumps(result,sort_keys=True))


if __name__=='__main__':main()
