import hashlib
import json
import os
import platform
import random
import time
from pathlib import Path
import candidate as c
import reference as ref

D = Path(__file__).resolve().parent
PROJECT = Path('/home/victor/IntelligenceRegulation')
NATIVE = PROJECT/'ops/zkp-mvp/trained-1b'
SEED = 20261030165
rng = random.Random(SEED)
checks = 0
controls = 0
t0 = time.monotonic()


def check(ok):
    global checks
    checks += 1
    assert ok, checks


def rejects(fn):
    try:
        fn()
    except (ValueError, OSError):
        return True
    return False


def negative(fn):
    global controls
    controls += 1
    check(rejects(fn))


def write_json(name, obj):
    (D/name).write_text(json.dumps(obj, indent=2)+'\n')


# Pin actual active backend and loader. The root compatibility adapter differs.
files = [
    'hashline/src/private_block/trained_block.rs', 'hashline/src/private_block/run.rs',
    'hashline/src/private_block.rs', 'hashline/src/gpu/mod.rs', 'hashline/src/gpu/cuda.rs',
    'hashline/src/private_block/protocol.rs', 'hashline/src/pcs.rs',
    'zkp-core/src/pcs.rs', 'zkp-core/src/pcs/backend.rs', 'zkp-core/src/pcs/encode_buffer.rs',
]
(D/'native').mkdir(exist_ok=True)
pins=[]
for path in files:
    p=NATIVE/path; b=p.read_bytes(); name=path.replace('/','__')
    (D/'native'/name).write_bytes(b)
    pins.append(dict(path=str(p),snapshot='native/'+name,sha256=hashlib.sha256(b).hexdigest(),bytes=len(b)))
write_json('native-pins.json',pins)

facts = [
 ('hashline/src/private_block/trained_block.rs','sealing_already_overlaps_next_load', 'let ((wres, ws), nxt) = rayon::join('),
 ('hashline/src/private_block/trained_block.rs','proving_cache_drops_before_reload','self.cur = None;'),
 ('hashline/src/private_block/trained_block.rs','actual_reloaded_block_authenticated','if blk.digest() != self.digests[k]'),
 ('hashline/src/private_block/trained_block.rs','cache_is_single_thread_rc_refcell','std::rc::Rc<std::cell::RefCell<BlockCache'),
 ('hashline/src/private_block/trained_block.rs','raw_arrays_parallel','expect.par_iter().map('),
 ('hashline/src/private_block/trained_block.rs','reload_skips_raw_hashes','self.load_layer_mode(sh, c, index, rope_from_export, false)?.blk'),
 ('hashline/src/private_block.rs','attention_copies_padded_words','wq: wq.to_vec()'),
 ('hashline/src/private_block.rs','ffn_copies_padded_words','wg_t: wg_t.to_vec()'),
 ('hashline/src/private_block/run.rs','demand_read_nofollow','opts.custom_flags(SEGMENT_OPEN_FLAGS)'),
 ('hashline/src/gpu/cuda.rs','upload_waits_for_completion','u.send(dst, 0, src).and_then(|_| u.wait())'),
 ('hashline/src/gpu/cuda.rs','device_entry_uploads_before_commit','g.upload_sync(d_data.get_mut(), as_u64s(data))?'),
 ('hashline/src/gpu/cuda.rs','device_attempt_uses_mutex','let mut g = g.lock().unwrap();'),
 ('hashline/src/gpu/cuda.rs','failed_resident_work_charged','let t_discarded = (t1.elapsed().as_secs_f64() - t_upload).max(0.0);'),
 ('hashline/src/gpu/mod.rs','required_gpu_decline_panics','if required() {'),
 ('zkp-core/src/pcs.rs','fresh_pads_before_offer','let pads = rng.fp_vec(rows * q);'),
 ('zkp-core/src/pcs.rs','fresh_salts_before_offer','let salts: Vec<[u8; 32]> = (0..nn).map(|_| rng.bytes32()).collect();'),
 ('zkp-core/src/pcs.rs','explicit_keyed_backend_offer','Some(key) => backend.try_commit_zk_keyed('),
 ('zkp-core/src/pcs.rs','cpu_fallback_reencodes_same_data','let encoded = encode_buffer::encode_rows(ntt, data_ref, n, &pads, q, &pows);'),
]
roster=[]
for path, role, literal in facts:
    text=(NATIVE/path).read_text(); check(literal in text)
    line=text[:text.index(literal)].count('\n')+1
    roster.append(dict(path=path,role=role,line=line,literal=literal))
# Order is significant: pads/salts/powers precede BOTH keyed and legacy offers.
pcs=(NATIVE/'zkp-core/src/pcs.rs').read_text().split('pub fn commit_zk_owned_with_tag',1)[1].split('\nimpl<E>',1)[0]
order=[pcs.index(s) for s in ['let pads =','let salts:', 'let pows =','let dev:']]
check(order==sorted(order))
write_json('source-roster.json',roster)

# Independent logical payload accounting over many public geometries.
# These are source-scope lower subtotals, not native capacities/fit/peaks.
geometries=[]
for d,f,qh,kh,hd in [(4,7,2,1,2),(8,13,4,2,2),(16,25,4,1,4),(4096,14336,32,8,128)]:
    for t in [17,32,64,128,256,512]:
        dp=1 << (d-1).bit_length(); fp=1 << (f-1).bit_length(); qp=1 << (qh*hd-1).bit_length()
        a=ref.logical_buffers(d,f,qh,kh,hd,dp,fp,qp,t)
        r=2*qh*hd*d+2*kh*hd*d+2*d+3*d*f+2560
        p=2*qp*dp+2*kh*hd*dp+2*dp+3*dp*fp
        tables=t*hd*8+2560
        expected={'raw11':r,'padded9':p,'returned':p+tables,'known_loader_payload':r+2*p+tables}
        for key,v in expected.items(): check(a[key]==v)
        a.update(dict(d=d,f=f,qh=qh,kh=kh,hd=hd,dp=dp,fp=fp,qp=qp,t=t,
                      old_public_plus_new_loader=a['returned']+a['known_loader_payload'],
                      public_only=True,native_execution=False,actual_capacity_fit=None))
        geometries.append(a)
write_json('logical-payloads.json',geometries)
selected=next(x for x in geometries if x['d']==4096 and x['t']==128)

# Exercise actual WILLNEED only on tiny newly authored synthetic public files.
# No cache flush, DONTNEED, model paths, threads, or speed benchmark.
base=D/'fixtures'; base.mkdir(exist_ok=True)
total_calls=0; advised_bytes=0; mutated_eager_accepts=0; mutation_cases=0
for fixture in range(16):
    folder=base/str(fixture); folder.mkdir(exist_ok=True)
    identity=('synthetic-public-model',fixture//4,'projection-v1','calibration-A',fixture)
    sizes=[17+fixture,7,7,19,4,4,31,31,31,32,16,24,24]
    specs=[(name+'.bin',size) for name,size in zip(['wq','wk','wv','wo','gamma_a','gamma_m','wg','wu','wd','exp','act','cos','sin'],sizes)]
    style=fixture%4
    bodies=[bytes(rng.randrange(256) for _ in range(n)) if style==0 else bytes([0 if style==1 else 255 if style==2 else i%256])*n for i,(_,n) in enumerate(specs)]
    for (name,n),b in zip(specs,bodies): (folder/name).write_bytes(b)
    hashes={name:hashlib.sha256(b).hexdigest() for (name,n),b in zip(specs,bodies)}
    # Fixture pin authored through explicit independent serialization.
    pre=b'research-public-loader-projection/v1\0'
    for part in identity:
        k=str(part).encode(); pre+=len(k).to_bytes(8,'little')+k
    for (name,n),b in zip(specs,bodies):
        key=name.encode(); pre+=len(key).to_bytes(8,'little')+key+n.to_bytes(8,'little')+b
    pin=hashlib.sha256(pre).hexdigest()
    for budget in [0,1,7,64,4096]:
        plan=c.ranges(specs,budget)
        check(sum(s for _,_,s in plan)==min(budget,sum(sizes)))
        check(all(s>0 and off==0 for _,off,s in plan))
        sent,errors=c.hint(folder,specs,budget)
        check(errors==0)
        check(sent==plan)
        total_calls+=len(sent); advised_bytes+=sum(s for _,_,s in sent)
        for full in [False,True]:
            h=hashes if full else None
            check(c.demand(folder,identity,specs,pin,h)==ref.load(folder,identity,specs,pin,h)==pre)
    eager=c.demand(folder,identity,specs,pin)
    # After hinting, replace or corrupt every array. Demand authentication stays.
    for j,(name,n) in enumerate(specs):
        path=folder/name; original=bodies[j]
        c.hint(folder,specs,64)
        changed=bytes([original[0]^1])+original[1:]
        for mutation in ['same-size','truncate','extend','replace','delete','symlink']:
            if path.is_symlink() or path.exists(): path.unlink()
            if mutation=='same-size': path.write_bytes(changed)
            elif mutation=='truncate': path.write_bytes(original[:-1])
            elif mutation=='extend': path.write_bytes(original+b'x')
            elif mutation=='replace':
                temp=folder/'replacement'; temp.write_bytes(changed); temp.replace(path)
            elif mutation=='symlink': path.symlink_to(folder/specs[(j+1)%len(specs)][0])
            for full in [False,True]:
                h=hashes if full else None
                negative(lambda:c.demand(folder,identity,specs,pin,h))
                negative(lambda:ref.load(folder,identity,specs,pin,h))
            # A hydrated old snapshot would still satisfy the old pin: altered
            # live-file refusal semantics, NOT a cryptographic forgery.
            check(hashlib.sha256(eager).hexdigest()==pin)
            mutated_eager_accepts+=1; mutation_cases+=1
        if path.is_symlink() or path.exists(): path.unlink()
        path.write_bytes(original)
    for j in range(len(identity)):
        changed=list(identity); changed[j]=str(changed[j])+'-other'
        negative(lambda:c.demand(folder,changed,specs,pin))
        negative(lambda:ref.load(folder,changed,specs,pin))
    def fail(*args): raise OSError('synthetic unsupported advice')
    sent,errors=c.hint(folder,specs,64,fail)
    check(sent==[] and errors>0)
    check(c.demand(folder,identity,specs,pin)==pre)
    negative(lambda:c.ranges(specs,-1))
    negative(lambda:c.ranges([('../outside',8)],64))
    # File size equality alone is not authority.
    negative(lambda:c.demand(folder,identity,list(reversed(specs)),pin))
write_json('advice-observations.json',dict(fixtures=16,actual_advice_calls=total_calls,
             actual_requested_range_bytes=advised_bytes,mutation_cases=mutation_cases,
             stale_eager_snapshot_accepts=mutated_eager_accepts,
             page_residency_measured=False,page_cache_memory_bound_proven=False,
             actual_hint_latency_benchmark=False,concurrent_race_test=False))

# Accepted device commitments consume private field data, not raw int8 model
# files. Public file advice cannot eliminate those fresh per-proof transfers.
traffic=[]
for rows in [1,37,4390,4577]:
    for n in [32,16384]:
        nn=4*n; q=min(256,n)
        for width in [1,2,4,8]:
            b=rows*n*width+(rows*q+nn)*8
            # Independent operand inventory and width: never assume int8 for
            # fresh masks or infer a real narrow-probe result from geometry.
            operands=[rows*n*width,rows*q*8,nn*8]
            check(b==sum(operands))
            traffic.append(dict(rows=rows,n=n,q=q,nn=nn,width_assumption=width,
                                one_commit_input_bytes=b,public_file_hint_removed_bytes=0,
                                includes_salting_trees=False,actual_runtime_eligibility=None))
write_json('commit-input-traffic.json',traffic)

write_json('hardware.json',dict(platform=platform.platform(),python=platform.python_version(),
          cpu_model=next((s.split(':',1)[1].strip() for s in Path('/proc/cpuinfo').read_text().splitlines() if s.startswith('model name')),'unknown'),
          affinity=sorted(os.sched_getaffinity(0)),gpu=False))
result=dict(status='PASS',seed=SEED,checks=checks,negative_controls=controls,
            public_geometry_cases=len(geometries),source_facts=len(roster),native_source_pins=len(pins),
            selected=selected,fixtures=16,mutation_cases=mutation_cases,
            actual_advice_calls=total_calls,actual_requested_range_bytes=advised_bytes,
            fresh_commit_input_bytes_eliminated=0,sealing_new_prefetch_incidence=0,
            native_prover=False,native_loader=False,proofs=0,complete_model_passes=0,proved_positions=0,
            target_clocks_and_rates=None,wall_s=time.monotonic()-t0)
write_json('result.json',result)
print(json.dumps({k:v for k,v in result.items() if k!='selected'}))
