"""Synthetic constructor differential, never a native proof or timing claim."""
import collections, hashlib, json, random, resource, time
from pathlib import Path
from reference import P, direct, encode, direct_mle

SEED=202610260127
R=random.Random(SEED)
C=collections.Counter()
CHECKS=0
START=time.monotonic()

def check(ok):
    global CHECKS
    CHECKS+=1
    assert ok, CHECKS

def k(v):
    C['from_i64']+=1
    assert -(1<<63) <= v < 1<<63
    return v % P,0

def add(a,b):
    C['add']+=1
    return (a[0]+b[0])%P,(a[1]+b[1])%P

def mul(a,b):
    C['mul']+=1
    return (a[0]*b[0]+7*a[1]*b[1])%P,(a[0]*b[1]+a[1]*b[0])%P

def row(i,table,beta,gamma):
    return add(add(k(i),mul(beta,k(table[i]))),gamma)

def literal(length,table,beta,gamma):
    return [row(x%256,table,beta,gamma) for x in range(length)]

def tiled(length,table,beta,gamma):
    out=[row(i,table,beta,gamma) for i in range(min(length,256))]
    while len(out)<length:
        take=min(length-len(out),len(out))
        assert 0<take<=len(out)
        # Models Rust extend_from_within; Python creates a temporary slice.
        # Rust's source-level payload accounting is audited separately.
        out.extend(out[:take])
        C['copy_rows']+=take
        C['copy_calls']+=1
    return out

def fold_base(rows,point):
    out=list(rows)
    for r in point:
        n=len(out)//2
        out=[((out[i][0]*(1-r)+out[i+n][0]*r)%P,
              (out[i][1]*(1-r)+out[i+n][1]*r)%P) for i in range(n)]
    return out[0]

def outcome(fn,*args):
    try:return 'OK',fn(*args)
    except (IndexError,ValueError) as e:return type(e).__name__,str(e)

lengths=[0,1,2,7,255,256,257,511,512,513,1023,1024,4096,16384,32768,65536,65537]
fixtures=[]
for q in range(6):
    exp=sorted([R.randrange(65537) for _ in range(256)],reverse=True)
    exp[0]=65536
    act=[R.randrange(-32768,32768) for _ in range(256)]
    act[:5]=[-32768,-1,0,1,32767]
    beta=[(0,0),(1,0),(0,1),(P-1,P-1),(R.randrange(P),R.randrange(P)),(R.randrange(P),R.randrange(P))][q]
    gamma=[(0,0),(0,1),(P-1,1),(7,P-1),(R.randrange(P),R.randrange(P)),(R.randrange(P),R.randrange(P))][q]
    fixtures.append((exp,act,beta,gamma))
entries=0; cases=0; counts=[]
for q,(exp,act,beta,gamma) in enumerate(fixtures):
    for kind,table in [('exp',exp),('act',act)]:
        for length in lengths:
            C.clear(); a=literal(length,table,beta,gamma); ca=dict(C)
            C.clear(); b=tiled(length,table,beta,gamma); cb=dict(C)
            oracle=direct(length,table,beta,gamma)
            check(a==oracle);check(b==oracle);check(encode(a)==encode(b))
            n=min(length,256)
            check(ca.get('mul',0)==length);check(cb.get('mul',0)==n)
            check(cb.get('add',0)==2*n);check(cb.get('from_i64',0)==2*n)
            check(cb.get('copy_rows',0)==length-n)
            check(len(b)==length)
            if length>=256:check(set(b)==set(direct(256,table,beta,gamma)))
            # Record source-level constructor counts once, not model timings.
            if q==4 and kind=='exp':counts.append(dict(length=length,baseline=ca,candidate=cb,
                output_payload_bytes=16*length,extra_separate_rust_scratch_bytes=0,
                new_logical_copy_read_bytes=16*(length-n),unchanged_output_store_bytes=16*length))
            entries+=length;cases+=1

# Exhaustively check copy schedules including partial tiles, without field work.
for length in range(1025):
    seed=list(range(min(length,256))); out=list(seed)
    while len(out)<length:out.extend(out[:min(length-len(out),len(out))])
    check(out==[i%256 for i in range(length)])

controls=[]
def control(name,ok):check(ok);controls.append(name)
exp,act,beta,gamma=fixtures[4]
base=direct(1024,exp,beta,gamma)
control('stale beta detected',base!=tiled(1024,exp,((beta[0]+1)%P,beta[1]),gamma))
control('stale gamma detected',base!=tiled(1024,exp,beta,(gamma[0],(gamma[1]+1)%P)))
changed=exp.copy();changed[17]-=1
control('public table change detected',base!=tiled(1024,changed,beta,gamma))
control('exp act confusion detected',base!=tiled(1024,act,beta,gamma))
control('incorrect modulo 255 detected',base!=[row(i%255,exp,beta,gamma) for i in range(1024)])
control('index lifted instead of repeated detected',base[256] != add(row(0,exp,beta,gamma),k(256)))
control('dropped extension coordinate detected',base!=[(a,0) for a,b in base])
control('rotated prefix detected',base!=base[1:]+base[:1])
control('fresh challenges alter SHA256 diagnostic bytes',hashlib.sha256(encode(base)).digest()!=hashlib.sha256(encode(tiled(1024,exp,beta,(1,2)))).digest())
# The helper itself has no shape refusal: malformed-table indexing is lazy.
# Typed act[256] cannot be malformed natively; these test adapter call order.
for length in [0,1,17,18,255,256,257,1024]:
    for size in [0,1,17,255,256,257]:
        table=list(range(size))
        check(outcome(literal,length,table,beta,gamma)==outcome(tiled,length,table,beta,gamma))
control('empty length never reads malformed table',tiled(0,[],beta,gamma)==[])
control('short input does not eagerly read 256 rows',tiled(1,[9],beta,gamma)==literal(1,[9],beta,gamma))
# Signed conversions broaden helper tests beyond valid checked exp tables.
extremes=[-(1<<63),(1<<63)-1,-32768,32767,-1,0,1]*37
check(tiled(4096,extremes[:256],beta,gamma)==direct(4096,extremes[:256],beta,gamma))
control('signed minimum conversion preserved',k(-(1<<63))==((-(1<<63))%P,0))
# All possible alpha coincidences retain the same denominator-zero positions.
# No inversions, masks or native refusal code are run by this check.
rows=tiled(1024,exp,beta,gamma)
for i in range(256):
    alpha=rows[i]
    ref=[j for j,v in enumerate(base) if v==alpha]
    candidate=[j for j,v in enumerate(rows) if v==alpha]
    check(ref==candidate)
control('padded denominator zero remains visible',rows[773]==rows[5])
# General off-Boolean point checks in the base subfield, direct cube vs fold.
mle_cases=0
for q in [0,2,4]:
    exp,act,beta,gamma=fixtures[q]
    for table in [exp,act]:
        for log in [0,7,8,9,10]:
            point=[R.randrange(P) for _ in range(log)]
            a=literal(1<<log,table,beta,gamma); b=tiled(1<<log,table,beta,gamma)
            check(fold_base(b,point)==direct_mle(a,point));mle_cases+=1

result=dict(status='PASS_SYNTHETIC_CONSTRUCTORS_ONLY',seed=SEED,checks=CHECKS,
    fixtures=len(fixtures),constructor_cases=cases,compared_output_entries=entries,
    lengths=lengths,copy_schedule_lengths=1025,malformed_adapter_cases=48,
    zero_denominator_alpha_cases=256,mle_cases=mle_cases,control_types=len(controls),controls=controls,
    source_api_counts=counts,elapsed_seconds=time.monotonic()-START,
    max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    native_proofs=0,oracle='Separately authored integer coordinate / original-cube MLE reference',
    limits='No native Rust, transcript, masks, PCS, GPU, receipt or privacy evidence. SHA256 diagnostic only.')
Path('result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='source_api_counts'}))
