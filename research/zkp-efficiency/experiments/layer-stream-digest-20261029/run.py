import os,resource,signal,time
resource.setrlimit(resource.RLIMIT_CPU,(40,40));resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,256*1024**2))
signal.alarm(45);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
import hashlib,json,random,struct,sys,platform
from pathlib import Path
import model
from reference import reference

START=time.perf_counter();ROOT=Path(__file__).resolve().parent;SEED=202610290132
rng=random.Random(SEED);checks=0;controls=[];fixtures=[];records=[]
def check(ok):
    global checks
    checks+=1
    if not ok:raise AssertionError(checks)
def refused(fn,name):
    try:fn()
    except (ValueError,KeyError,TypeError): controls.append(name);check(True)
    else:raise AssertionError('accepted '+name)
def enc(m):return json.dumps(m,separators=(',',':')).encode()
def fresh(m):return json.loads(json.dumps(m))
geometries=[(8,9,4,2,2,8,16,4,3),(12,9,6,2,2,16,16,8,3),
    (16,16,8,2,2,16,16,8,4),(3,5,2,1,2,4,8,2,3),
    (8,7,3,1,2,8,8,4,3),(12,8,6,2,2,16,8,8,3),
    (8,8,4,2,2,8,8,4,4),(6,4,4,2,2,8,4,4,3)]
for gi,g in enumerate(geometries):
  for style in ('random','edge','zero','ramp'):
    layer=gi; contents={};m={'layer':layer,'arrays':{}}
    for ai,(n,(dt,shape)) in enumerate(model.specs(g).items()):
        count=1
        for d in shape:count*=d
        bits={'i8':8,'i16':16,'i64':64}[dt];hi=(1<<(bits-1))-1;lo=-(1<<(bits-1))
        vals=[rng.randint(-128,127) if style=='random' else (lo,hi,-1,0,1)[j%5] if style=='edge' else 0 if style=='zero' else (j*17+ai)%255-127 for j in range(count)]
        code={'i8':'b','i16':'h','i64':'q'}[dt];raw=struct.pack('<'+str(count)+code,*vals)
        contents[n+'.bin']=raw;m['arrays'][n]={'file':n+'.bin','dtype':dt,'shape':shape,'sha256':model.sha(raw)}
    mb=enc(m);ref,bref,pref=reference(g,layer,mb,contents)
    for chunk in (1,7,64,257):
        got,b,p,stats=model.construct_record(g,layer,mb,contents,chunk)
        check(got==ref);check(b==bref);check(p==pref)
        for n in stats['reused']:check(contents[n+'.bin']==b[n])
        expected=sum(len(v) for v in b.values())-sum(len(b[n]) for n in stats['reused'])
        check(stats['padded_sha_bytes']==expected)
    records.append(ref)
    fixtures.append({'geometry':g,'style':style,'reused':stats['reused'],
        'baseline_record_sha_bytes':sum(map(len,b.values())),
        'candidate_record_sha_bytes':stats['padded_sha_bytes'],
        'eliminated_record_sha_bytes':sum(len(b[n]) for n in stats['reused']),
        'canonical_preimage_sha256':model.sha(pref)})
    # Every raw source mutation must be refused under the original manifest.
    for n in model.specs(g):
        changed=contents.copy();v=bytearray(changed[n+'.bin']);v[len(v)//2]^=1;changed[n+'.bin']=bytes(v)
        refused(lambda:model.construct_record(g,layer,mb,changed),n+' raw mutation')
        refused(lambda:reference(g,layer,mb,changed),n+' independent raw mutation')
        # Even a rehashed changed export is caught by the original actual
        # block digest binding; the raw hash itself is not model authority.
        altered=fresh(m);altered['arrays'][n]['sha256']=model.sha(changed[n+'.bin'])
        updated,_,pre_new,_=model.construct_record(g,layer,enc(altered),changed)
        check(pre_new!=pref);check(updated['canonical_preimage_sha256_SURROGATE']!=ref['canonical_preimage_sha256_SURROGATE'])
        controls.append(n+' rehashed stale-block statement')
        # false/reload has no checked raw SHA capability: all record fields
        # recomputed from actual rebuilt bytes, never from manifest want.
        reload_rec,_,reload_pre,reload_stats=model.construct_record(g,layer,mb,changed,full=False)
        check(reload_stats['reused']==[]);check(reload_pre!=pref)
        check(reload_rec['canonical_preimage_sha256_SURROGATE']!=ref['canonical_preimage_sha256_SURROGATE'])
        controls.append(n+' reload rebuilt-digest')
    for n in ('wq','exp','act'):
        for field,value in [('dtype','f32'),('shape',[1]),('file','../escape')]:
            bad=fresh(m);bad['arrays'][n][field]=value
            refused(lambda:model.construct_record(g,layer,enc(bad),contents),n+' '+field)
            refused(lambda:reference(g,layer,enc(bad),contents),n+' independent '+field)
        short=contents.copy();short[n+'.bin']=short[n+'.bin'][:-1]
        refused(lambda:model.construct_record(g,layer,mb,short),n+' length')
    refused(lambda:model.construct_record(g,layer+1,mb,contents),'changed layer')
    # Object key order is not native array order: accepted, same block bytes,
    # but original raw manifest identity still changes.
    reorder=fresh(m);reorder['arrays']=dict(reversed(list(reorder['arrays'].items())))
    a,_,pp,_=model.construct_record(g,layer,enc(reorder),contents)
    check(pp==pref);check(a['word_sha256']==ref['word_sha256']);check(a['manifest_sha256']!=ref['manifest_sha256'])
    for n in model.NAMES:
        if not model.identity_route(model.routes(g)[n]):
            check(model.sha(contents[n+'.bin'])!=ref['word_sha256'][model.NAMES.index(n)])
            controls.append(n+' unconditional reuse wrong with padding')
    # Neither concatenating final RoPE hashes nor using a single RoPE hash
    # reproduces SHA256(cos_bytes || sin_bytes).
    check(model.sha(bytes.fromhex(m['arrays']['rope_cos']['sha256'])+bytes.fromhex(m['arrays']['rope_sin']['sha256']))!=ref['table_sha256'][0])
    controls.append('cannot concatenate finalized RoPE hashes')

# General transformation predicate controls: same extents alone not enough.
r=(2,2,2,2,(1,0),(0,1));check(not model.identity_route(r));check(model.scatter(bytes([1,2,3,4]),r)!=bytes([1,2,3,4]));controls.append('same extent permuted rows')
r=(2,2,2,2,(0,1),(1,0));check(not model.identity_route(r));controls.append('same extent permuted columns')
for profile2 in ('other model','changed calibration','changed source format'):
    check(model.binding(profile2,records[:2])!=model.binding('baseline',records[:2]));controls.append(profile2+' outer binding')
check(model.binding('baseline',records[:2])!=model.binding('baseline',list(reversed(records[:2]))));controls.append('ordered layers')
check(model.binding('baseline',records[:2])!=model.binding('baseline',[records[0],records[0]]));controls.append('layer multiplicity')
ref=records[0];forged=dict(ref);forged['word_sha256']=list(ref['word_sha256']);forged['word_sha256'][0]='00'*32
check(forged!=ref);controls.append('caller digest is not authority')

# Allocation-free production geometry census: no model bytes accessed.
target=(4096,14336,32,8,128,4096,16384,32,128)
rs=model.routes(target);eligible={n:rs[n][0]*rs[n][1] for n in model.NAMES if model.identity_route(rs[n])}
raw_sizes={n:r[0]*r[1] for n,r in rs.items()};pad_sizes={n:r[2]*r[3] for n,r in rs.items()}
reused_layer=sum(eligible.values())+256*8+256*2
all_record_layer=sum(pad_sizes.values())+2*128*64*8+256*8+256*2
check(set(eligible)=={'wq','wk','wv','wo','gamma_a','gamma_m'})
check(reused_layer==41953792)
census={'geometry':target,'eligible_i8_bytes':eligible,'reused_exp_act_bytes':2560,
    'reused_record_sha_bytes_per_full_layer':reused_layer,'reused_record_sha_bytes_per_32_layer_full_scan':32*reused_layer,
    'baseline_record_sha_bytes_per_full_layer':all_record_layer,
    'fraction_of_record_sha_input_removed':reused_layer/all_record_layer,
    'reload_saved_sha_bytes':0,'blk_digest_saved_bytes':0,
    'largest_eligible_i8_cast_temporary_bytes':max(eligible.values()),
    'largest_remaining_i8_cast_temporary_bytes':max(pad_sizes[n] for n in model.NAMES if n not in eligible),
    'raw_bytes_per_layer':sum(raw_sizes.values())+2*128*64*8+2560,
    'passes':[{'passes':p,'full_scan_savings_if_full_load_each_pass_bytes':p*32*reused_layer,
       'full_scan_savings_if_setup_once_bytes':32*reused_layer,
       'proof_positions':0} for p in (1,2,4,8)],
    'scope':'logical SHA input/cast sizes, not DRAM, peak RSS, elapsed, VRAM or proof throughput'}
for p in ('model.py','reference.py','run.py'):
    check((ROOT/p).is_file())
proof={'independently_verified_full_stack_proofs':0,'passes':0,'countable_positions':0,
    'context_length':None,'device':'CPU checking only; no model or GPU',
    'startup_s':None,'prefill_s':None,'startup_fraction':None,'witness_s':None,
    'proof_s':None,'serialization_s':None,'verification_s':None,'steady_state_positions_s':None,
    'total_workload_positions_s':None,'proof_latency_s':None,'proof_bytes':None,
    'prefill':'none','resident_model_passes':'none','decode':'none'}
result={'status':'PASS_SYNTHETIC_CONTRACT_ONLY','seed':SEED,'checks':checks,'negative_controls':len(controls),
    'control_names':controls,'fixtures':fixtures,'census':census,
    'elapsed_s':time.perf_counter()-START,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    'hardware':{'cpu':next(l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),
        'affinity':sorted(os.sched_getaffinity(0)),'threads':1,'python':sys.version,'platform':platform.platform(),'GPU':False},
    'limits':{'CPU_s':40,'alarm_s':45,'AS_MiB':256,'estimated_memory_MiB':64},
    'source_hashes':{n:model.sha((ROOT/n).read_bytes()) for n in ('model.py','reference.py','run.py')},'proof_accounting':proof}
(ROOT/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:result[k] for k in ('status','checks','negative_controls','elapsed_s','peak_rss_kib')}))
print(json.dumps(census,indent=2))
