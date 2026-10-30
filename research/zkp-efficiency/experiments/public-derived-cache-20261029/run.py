"""One-thread <=45s <=256MiB authored contract experiment. No real model data."""
import os,resource,signal,sys,time
resource.setrlimit(resource.RLIMIT_CPU,(40,40));resource.setrlimit(resource.RLIMIT_AS,(256<<20,256<<20));signal.alarm(45)
os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from pathlib import Path
import copy,dataclasses,hashlib,json,random,struct,platform
from collections import Counter
import model
from reference import reference

D=Path(__file__).resolve().parent;SEED=202610290131; rng=random.Random(SEED);counts=Counter();controls=[];fixtures=[]
t0=time.perf_counter()
def check(k,condition):
    assert condition,k
    counts[k]+=1
def refuse(k,fn):
    try:fn()
    except (ValueError,FileNotFoundError,OSError,KeyError,struct.error,dataclasses.FrozenInstanceError) as e:
        counts['negative_control']+=1;controls.append({'name':k,'refusal':str(e)});return
    raise AssertionError('did not refuse '+k)
def bf(v):return b''.join(struct.pack('<f',x)[2:] for x in v)
def make(v,w,block,style):
    rows=[rng.randint(-32,32)/8 for _ in range(v*w)]
    if style=='zero-row':rows[:w]=[0.]*w
    norm=[rng.choice([.5,1.,1.5,2.]) for _ in range(w)]
    tb=bf(rows);nb=bf(norm);h={'embedding':{'dtype':'BF16','shape':[v,w],'data_offsets':[0,len(tb)]},'norm':{'dtype':'BF16','shape':[w],'data_offsets':[len(tb),len(tb)+len(nb)]}}
    hb=model.wire(h);cp=struct.pack('<Q',len(hb))+hb+tb+nb+b'SYNTHETIC PUBLIC FILLER'
    sb=struct.pack('<'+'d'*w,*[rng.choice([-1.,1.]) for _ in range(w)])
    p={'vocab':v,'width':w,'block':block,'checkpoint_size':len(cp),'checkpoint_sha256':model.sha(cp),'tensor_sha256':model.sha(tb),'sign_sha256':model.sha(sb),'residual_scale':.125,'margin':{'yes':0,'no':v-1,'scale':.0625,'threshold_c':0},'calibration':{'bos':1,'classifier_norm':{'g0':127,'cn':1024,'tn':10,'ceps':2439},'head_norm':{'g0':127,'cn':1024,'tn':10,'ceps':2439}},'profile':'SYNTHETIC NOT NATIVE','source_version':'r12b-model-1'}
    return p,sb,cp

for v in [2,3,8,17]:
 for w,block in [(4,4),(8,4),(16,16),(32,16)]:
  for style in ['random','zero-row']:
    p,sb,cp=make(v,w,block,style);pb=model.wire(p)
    derived=model.derive(pb,sb,cp);ds,margin,tables=reference(pb,sb,cp,binary64=True)
    exact_ds,exact_margin,exact_tables=reference(pb,sb,cp)
    check('rational_diagnostic_comparison',len(exact_ds)==len(ds)==3 and len(exact_margin)==len(margin))
    if exact_ds!=ds:
      counts['rational_differs_from_binary64']+=1
    check('digest_differential',derived.digests==ds)
    check('margin_differential',derived.margin==margin)
    check('base_projection',derived.use(pb,model.sha(pb))[0]==ds)
    model.validate_tables(derived,tables);counts['table_validation']+=1
    for passes in [1,2,4,8]:
      for _ in range(passes):check('resident_immutable_reuse',derived.use(pb,model.sha(pb))[:2]==(ds,margin))
    # Every bound profile change must miss, even changes without numerical effects.
    mutations=[]
    for key,new in [('residual_scale',.25),('block',block*2),('checkpoint_sha256','0'*64),('tensor_sha256','1'*64),('sign_sha256','2'*64),('source_version','r12b-model-2'),('profile','SYNTHETIC OTHER')]:
      q=copy.deepcopy(p);q[key]=new;mutations.append((key,q))
    for key,new in [('yes',1),('no',0),('scale',.125),('threshold_c',1)]:
      q=copy.deepcopy(p);q['margin'][key]=new;mutations.append(('margin.'+key,q))
    for key in ['bos','classifier_norm','head_norm']:
      q=copy.deepcopy(p)
      if key=='bos':q['calibration'][key]=2
      else:q['calibration'][key]['cn']+=1
      mutations.append(('calibration.'+key,q))
    for key,q in mutations:
      qb=model.wire(q);refuse('stale '+key,lambda qb=qb:derived.use(qb,model.sha(qb)))
    refuse('wrong caller statement digest',lambda:derived.use(pb,'f'*64))
    refuse('algorithm version',lambda:derived.use(pb,model.sha(pb),'new'))
    refuse('immutable result assignment',lambda:setattr(derived,'margin',(123,)))
    refuse('profile byte identity whitespace',lambda:derived.use(pb+b' ',model.sha(pb)))
    for ti in range(3):
      bad=list(tables);t=bytearray(bad[ti]);t[0]^=1;bad[ti]=bytes(t)
      refuse('forged exported table '+str(ti),lambda bad=bad:model.validate_tables(derived,bad))
    # Hashing then re-reading a mutable tensor must authenticate the consumed bytes.
    offset=8+int.from_bytes(cp[:8],'little');changed=bytearray(cp);changed[offset]^=1
    refuse('consumed tensor changed after full hash',lambda:model.derive(pb,sb,cp,bytes(changed)))
    changed=bytearray(cp);changed[-1]^=1
    refuse('full checkpoint filler changed',lambda:model.derive(pb,sb,bytes(changed)))
    refuse('sign bytes changed',lambda:model.derive(pb,bytes([sb[0]^1])+sb[1:],cp))
    for ids in [(0,0),(-1,1),(0,v)]:
      q=copy.deepcopy(p);q['margin']['yes'],q['margin']['no']=ids
      refuse('invalid ids '+str(ids),lambda q=q:model.derive(model.wire(q),sb,cp))
    for val in [0.,-0.,-1.,float('nan'),float('inf')]:
      q=copy.deepcopy(p);q['margin']['scale']=val
      refuse('invalid scale '+str(val),lambda q=q:model.derive(model.wire(q),sb,cp))
    q=copy.deepcopy(p);q['margin']['scale']=2**-30
    refuse('margin refuses without clipping',lambda:model.derive(model.wire(q),sb,cp))
    fixtures.append({'vocab':v,'width':w,'block':block,'style':style,'profile_sha256':model.sha(pb),'checkpoint_sha256':model.sha(cp),'table_digests':ds,'margin_sha256':model.sha(struct.pack('<'+'h'*w,*margin)),'rational_matches':exact_ds==ds and exact_margin==margin,'head_byte_differences_vs_rational':[{'index':i,'binary64':a if a<128 else a-256,'rational':c if c<128 else c-256} for i,(a,c) in enumerate(zip(tables[1],exact_tables[1])) if a!=c]})

# Filesystem controls operate exclusively on synthetic files in this experiment.
F=D/'fixtures';F.mkdir(exist_ok=True);p,sb,cp=make(3,8,4,'random');pb=model.wire(p);path=F/'synthetic-checkpoint.bin';path.write_bytes(cp)
derived=model.derive(pb,sb,model.read_regular(path,len(cp)));old=os.stat(path)
weak_key=lambda st:(str(path),st.st_dev,st.st_ino,st.st_size,st.st_mtime_ns)
cache={weak_key(old):derived};changed=bytearray(cp);changed[-1]^=1;path.write_bytes(changed);os.utime(path,ns=(old.st_atime_ns,old.st_mtime_ns))
check('metadata_key_collision',weak_key(os.stat(path))==weak_key(old))
check('unsafe_metadata_cache_accepts_stale',cache[weak_key(os.stat(path))]==derived)
refuse('live file mutation',lambda:model.derive(pb,sb,model.read_regular(path,len(cp))))
check('snapshot_remains_original',derived.use(pb,model.sha(pb))[:2]==reference(pb,sb,cp,binary64=True)[:2])
path.unlink();refuse('live missing file',lambda:model.read_regular(path,len(cp)))
check('snapshot_different_refusal_domain',derived.use(pb,model.sha(pb))[:2]==reference(pb,sb,cp,binary64=True)[:2])
path.write_bytes(cp);link=F/'synthetic-link'
if os.path.lexists(link):link.unlink()
link.symlink_to(path.name);refuse('symlink',lambda:model.read_regular(link,len(cp)))
fifo=F/'synthetic-fifo'
if os.path.lexists(fifo):fifo.unlink()
os.mkfifo(fifo);refuse('fifo without blocking',lambda:model.read_regular(fifo,len(cp)));fifo.unlink();link.unlink()
refuse('wrong file extent',lambda:model.read_regular(path,len(cp)-1))

# Additional source-shaped extent/rotation/normalization negatives.
headlen=int.from_bytes(cp[:8],'little');header=json.loads(cp[8:8+headlen]);base=8+headlen
for label,mut in [('dtype',lambda h:h['embedding'].update(dtype='F16')),('shape',lambda h:h['embedding'].update(shape=[8,3])),('offset',lambda h:h['embedding'].update(data_offsets=[-1,47])),('independent head',lambda h:h.update(lm_head={}))]:
    h=copy.deepcopy(header);mut(h);hb=model.wire(h);bad=struct.pack('<Q',len(hb))+hb+cp[base:];q=copy.deepcopy(p);q['checkpoint_sha256']=model.sha(bad);q['checkpoint_size']=len(bad)
    refuse('malformed '+label,lambda q=q,bad=bad:model.derive(model.wire(q),sb,bad))
bad=bytearray(sb);bad[:8]=struct.pack('<d',0.);q=copy.deepcopy(p);q['sign_sha256']=model.sha(bad)
refuse('zero rotation sign',lambda:model.derive(model.wire(q),bytes(bad),cp))
refuse('nonfinite BF16',lambda:model.values(bytes.fromhex('807f')))
# Norm used by the transform must be the bytes captured by full authentication,
# even if an adversary changes the later file view's norm.
phase2=bytearray(cp);normlo=base+header['norm']['data_offsets'][0];phase2[normlo:normlo+2]=bf([7.])
check('norm_same_authenticated_reads',model.derive(pb,sb,cp,bytes(phase2))==derived)
# A proposed two-row-only derivation loses global head multiplier calibration.
q,s2,c2=make(3,4,4,'random');b2=model.wire(q);orig=model.derive(b2,s2,c2)
n2=int.from_bytes(c2[:8],'little');off2=8+n2;changed=bytearray(c2);changed[off2+8:off2+16]=bf([100.,100.,100.,100.])
q['checkpoint_sha256']=model.sha(changed);q['tensor_sha256']=model.sha(changed[off2:off2+24]);new=model.derive(model.wire(q),s2,bytes(changed))
check('nonselected_row_changes_global_multipliers',orig.digests[2]!=new.digests[2])
check('nonselected_row_keeps_margin',orig.margin==new.margin)

check('negative_tie_rounding',model.quant([-2.5,-1.5,-.5,.5,1.5],1.,-10,10)==[-2,-1,0,1,2])
check('difference_before_quantization_control',model.quant([.49-(-.49)],1.,-10,10)!=[model.quant([.49],1.,-10,10)[0]-model.quant([-.49],1.,-10,10)[0]])
# A public dataclass is intentionally NOT claimed as a security capability.
forged=dataclasses.replace(derived,margin=(0,)*8)
check('public_constructible_result_is_not_capability',forged.use(pb,model.sha(pb))!=derived.use(pb,model.sha(pb)))
rows=[]
for passes in [1,2,4,8]:
    # Source-derived count-only schedules, not observed native runtime incidence.
    rows.append({'passes':passes,'baseline_two_sites_derivations':2*passes,'shared_per_request_derivations':passes,'explicit_resident_session_derivations':1,'immutable_inputs_required':True})
observations={'rational_differs_from_binary64':counts.pop('rational_differs_from_binary64',0)}
out={'status':'PASS_SYNTHETIC_CONTRACT_ONLY','seed':SEED,'fixture_count':len(fixtures),'fixtures':fixtures,'checks':sum(counts.values()),'checks_by_kind':dict(counts),'observations':observations,'negative_controls':controls,'count_only_schedules':rows,'elapsed_s':time.perf_counter()-t0,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'hardware':{'cpu':next((l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),platform.processor()),'affinity':sorted(os.sched_getaffinity(0)),'threads':1,'device':'CPU only; no GPU'},'limits':{'CPU_s':40,'alarm_s':45,'address_space_MiB':256,'estimated_memory_MiB':64},'code_hashes':{name:model.sha((D/name).read_bytes()) for name in ['model.py','reference.py','run.py']},'proof_accounting':{'independently_verified_full_stack_proofs':0,'passes':0,'countable_positions':0,'context_length':None,'startup_s':None,'prefill_s':None,'startup_fraction':None,'witness_s':None,'proof_s':None,'serialization_s':None,'verification_s':None,'steady_state_positions_s':None,'total_workload_positions_s':None,'latency_s':None,'proof_bytes':None,'prefill':'none','resident_model_passes':'none','decode':'none'}}
(D/'result.json').write_text(json.dumps(out,indent=2,allow_nan=False)+'\n');print(json.dumps({k:out[k] for k in ['status','checks','checks_by_kind','fixture_count','elapsed_s','peak_rss_kib']}))
