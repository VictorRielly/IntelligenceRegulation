import hashlib,itertools,json,platform,random,resource,time
from pathlib import Path
import candidate as c
import reference as r

HERE=Path(__file__).resolve().parent
SEED=202610290137
rng=random.Random(SEED);start=time.monotonic();checks=0;fixtures=[];controls={}
def check(test):
    global checks
    checks+=1
    assert test,checks
def random_fp():return rng.randrange(c.P)
def random_ext():return random_fp(),random_fp()
def wire(values):return b''.join(a.to_bytes(8,'little')+b.to_bytes(8,'little') for a,b in values)
def dot_reference(eq,x,y):
    acc=(0,0)
    for e,a,b in zip(eq,x,y):acc=r.plus(acc,r.product(e,(a,b)))
    return acc

edge=[0,1,2,7,2**32-1,2**32,2**63,c.P-2,c.P-1]
for a,b in itertools.product(edge,repeat=2):
    check(c.add(a,b)==(a+b)%r.Q);check(c.sub(a,b)==(a-b)%r.Q);check(c.mul(a,b)==a*b%r.Q)
for a,b,x,y in itertools.product([0,1,7,2**32,c.P-2,c.P-1],repeat=4):
    check(c.paired([(a,b)],[x],[y])==r.product((a,b),(x,y)))
for _ in range(4096):
    a,b,x,y=[random_fp() for _ in range(4)]
    check(c.paired([(a,b)],[x],[y])==r.product((a,b),(x,y)))
for n in [0,1,2,3,7,31,127,1025]:
    eq=[random_ext() for _ in range(n)];x=[random_fp() for _ in range(n)];y=[random_fp() for _ in range(n)]
    ref=dot_reference(eq,x,y)
    for mode in ['three','four']:check(c.paired(eq,x,y,mode)==ref)
    check(c.baseline(eq,x,y)==ref)

for row_log in range(9):
    for private_log in sorted({0,max(0,row_log-1),row_log,row_log+2}):
        for kind in ['extension','base','boolean','zero-first','max']:
            point=[random_ext() for _ in range(private_log)]
            if kind=='base':point=[(random_fp(),0) for _ in point]
            if kind=='boolean':point=[(rng.randrange(2),0) for _ in point]
            if kind=='max':point=[(c.P-1,c.P-1) for _ in point]
            if kind=='zero-first' and point:point[0]=(0,0)
            n=1<<row_log;length=1<<min(row_log,private_log)
            offset=(n-length) if private_log<row_log else 3*n
            data=[random_fp() for _ in range(6*n)]
            masks=[]
            for mask_row in [0,2,4]:
                ref=r.evaluation(data,row_log,private_log,offset,mask_row,point)
                for mode in ['baseline','four','three']:
                    check(c.evaluate(data,row_log,private_log,offset,mask_row,point,mode)==ref)
                masks.append(ref)
            initial=[random_ext() for _ in masks];es=[random_ext() for _ in range(3)];rounds=[0,1,2]
            expected=r.extension(initial,masks,rounds,es);actual=list(initial)
            # Independently spell the candidate recurrence; retain later zeros.
            for m,t in enumerate(es):
                for k,v in enumerate(actual):
                    actual[k]=c.fadd(c.fmul((c.sub(1,t[0]),c.sub(0,t[1])),v),c.fmul(t,masks[k] if rounds[k]==m else (0,0)))
            check(wire(actual)==wire(expected))
            fixtures.append({'row_log':row_log,'private_log':private_log,'kind':kind,'offset':offset,
                             'sites':3,'terminal_sha256':hashlib.sha256(wire(actual)).hexdigest()})

for row_log in [8,13,14]:
    n=1<<row_log;point=[random_ext() for _ in range(row_log)]
    data=[random_fp() for _ in range(12*n)];masks=[]
    for mask_row in range(0,12,2):
        ref=r.evaluation(data,row_log,row_log,0,mask_row,point,large=True)
        for mode in ['baseline','four','three']:check(c.evaluate(data,row_log,row_log,0,mask_row,point,mode)==ref)
        masks.append(ref)
    fixtures.append({'row_log':row_log,'private_log':row_log,'kind':'six-distinct-pairs',
                     'sites':6,'mask_sha256':hashlib.sha256(wire(masks)).hexdigest()})

# All deliberately wrong alternatives must be distinguished by witnesses.
eq=[(c.P-1,c.P-2),(11,13),(17,19)]
x=[c.P-1,23,29];y=[c.P-2,31,37];ref=dot_reference(eq,x,y)
a=sum(e[0]*v for e,v in zip(eq,x))%c.P
b=sum(e[1]*v for e,v in zip(eq,y))%c.P
d=sum(((e[0]+e[1])%c.P)*((u+v)%c.P) for e,u,v in zip(eq,x,y))%c.P
bad={
 'wrong-nonresidue':((a+5*b)%c.P,(d-a-b)%c.P),
 'missing-sub-a':((a+7*b)%c.P,(d-b)%c.P),
 'missing-sub-b':((a+7*b)%c.P,(d-a)%c.P),
 'unreduced-eq-sum':((a+7*b)%c.P,(sum(((e[0]+e[1])&c.W)*((u+v)%c.P) for e,u,v in zip(eq,x,y))-a-b)%c.P),
 'unreduced-private-sum':((a+7*b)%c.P,(sum(((e[0]+e[1])%c.P)*((u+v)&c.W) for e,u,v in zip(eq,x,y))-a-b)%c.P),
 'drop-last':c.paired(eq[:-1],x[:-1],y[:-1]),
 'reuse-real-row':c.paired(eq,x,x),
 'swap-limbs':ref[::-1],
 'wrong-eq':c.paired(list(reversed(eq)),x,y),
}
for label,v in bad.items():check(v!=ref);controls[label]=True
data=[random_fp() for _ in range(6*32)];point=[random_ext() for _ in range(3)]
ref=r.evaluation(data,5,3,16,2,point)
for label,args in [('wrong-offset',(5,3,8,2,point)),('wrong-width',(4,3,16,2,point)),
                   ('wrong-pair',(5,3,16,0,point)),('reverse-tail',(5,3,16,2,point[::-1]))]:
    check(c.evaluate(data,*args)!=ref);controls[label]=True
new_data=data[:];new_data[2*32+16]=c.add(new_data[2*32+16],1)
check(c.evaluate(new_data,5,3,16,2,point)!=ref);controls['stale-private-result']=True
masks=[(3,5),(7,11)];initial=[(13,17),(19,23)];es=[(29,31),(37,41)]
ref=r.extension(initial,masks,[0,1],es)
check(r.extension(initial,masks,[1,0],es)!=ref);controls['wrong-extension-round']=True
once=r.extension(initial,masks,[0,1],es[:1])
check([once[0],ref[1]]!=ref);controls['omit-later-zero-extension']=True
check(wire(ref)!=wire(ref[::-1]));controls['wrong-terminal-order']=True
check((2*(c.P-1)**2)>2**128-1);controls['unsafe-u128-raw-sum-bound']=True
for n in [1,2,3,256,8192,16384]:
    counts=c.counts(n);check(counts['baseline']['variable_mul']-counts['three']['variable_mul']==n)
    check(counts['three']['add']-counts['baseline']['add']==n-1)
    check(counts['three']['private_word_reads']==counts['baseline']['private_word_reads'])

result={'status':'PASS','seed':SEED,'checks':checks,'fixtures':fixtures,'fixture_count':len(fixtures),
        'negative_controls':controls,'primitive_extrema_products':6**4,'primitive_random_products':4096,
        'counts':[c.counts(n) for n in [1,256,8192,16384]],'elapsed_s':time.monotonic()-start,
        'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        'hardware':{'cpu':next((s.split(':',1)[1].strip() for s in Path('/proc/cpuinfo').read_text().splitlines() if s.startswith('model name')),None),
                    'platform':platform.platform(),'python':platform.python_version(),'threads':1},
        'model_context':None,'accelerator':None,'full_stack_proofs':0,'passes':0,'proved_positions':0,
        'witness_s':None,'proof_s':None,'serialization_s':None,'verification_s':None,'startup_s':None,
        'initial_prefill_s':None,'startup_fraction':None,'steady_proved_positions_per_s':None,'total_proved_positions_per_s':None,
        'limitations':['Python algebra/word-count model only','No native compile, mask/refusal/transcript/PCS/privacy or receipt test',
                       'Source loop equality loads are not DRAM traffic','No added persistent scratch; actual peak/register delta unknown']}
(HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['fixtures','counts']},indent=2))
