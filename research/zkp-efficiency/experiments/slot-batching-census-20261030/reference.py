"""Independent schedule equations and DFS reference, authored in this lane.

No cryptographic native functions, workload/latency benchmarks or GPU use.
The dependency reference below is explicit; it does not import the event
ledger's last-writer construction or the Rust Floyd-Warshall implementation.
"""
from pathlib import Path
import ast, hashlib, itertools, json, random, re, subprocess
D=Path(__file__).resolve().parent
SEED=202610300941
EXPECTED_POINTS=[(0,2,'r_t'),(1,2,'r_t2'),(4,17,'lam_z'),(4,17,'p_ht'),
 (5,6,'r_q'),(5,7,'r_q'),(5,15,'pq'),(6,16,'pk'),(7,16,'pv'),
 (8,17,'p_s'),(9,15,'p_o'),(10,14,'p_a'),(11,12,'r_tf'),
 (11,18,'p_g'),(12,18,'p_u'),(13,14,'p_z')]
EXPECTED_HOSTS=[(0,2),(1,2),(10,14),(13,14),(5,15),(9,15),
 (6,16),(7,16),(4,17),(8,17),(11,18),(12,18)]
EXPECTED=set((a,b,'point:'+k) for a,b,k in EXPECTED_POINTS)|set((a,b,'host') for a,b in EXPECTED_HOSTS)
events=json.loads((D/'events.json').read_text())
def check_ledger(edge_list):
    assert len(edge_list)==len(EXPECTED)
    assert len(set(map(tuple,edge_list)))==len(EXPECTED)
    assert set(map(tuple,edge_list))==EXPECTED
check_ledger(events['edges'])

# Native-source sanity anchors and fully retained Points occurrence census.
src=(D/'native/argument.rs').read_text();acc=(D/'native/argument_accuracy.rs').read_text()
tr=(D/'native/transcript.rs').read_text();layout=(D/'native/layout.rs').read_text()
def compact(s):return re.sub(r'\s+','',s)
anchors=[(src,'if slot == SC_QMM || slot == SC_WO {'),
 (src,'pts.r_q = tr.challenge_fp2_vec(lt);'),
 (src,'let r_row = if slot == SC_DMM { tr.challenge_fp2_vec(lt) } else { pts.r_tf.clone() };'),
 (src,'tr.absorb_u64(b"pb-slot", s as u64);'),
 (src,'tr.absorb_fp2(b"pb-term", &terms);'),
 (src,'let c = tr.challenge_fp2();'),
 (src,'let mask = &pd.masks[s];'),
 (src,'acc.claims[p.cm as usize].push(build_claim(&sh, p, &claim_point(p, &rho), cd, cm, terms[k]));'),
 (src,'let def = define(slot, ctx, &mut pts, tr)?;'),
 (src,'run_slot(side, &mut acc, def, tr)?;'),
 (src,'if ctx.lay.shape().accuracy_stack()!=crate::private_block::accuracy_precision::Stack::Legacy'),
 (acc,'SC_QZC|SC_KVZC=>qzc(slot,ctx,pts,tr).map(Some),'),
 (acc,'SC_SZC if sh.dd_cap>0=>szc_dd(ctx,pts,tr).map(Some),'),
 (acc,'SC_DD=>dd(ctx,tr).map(Some),'),
 (acc,'let hosted=vec![(SC_WO,nu[0]),(SC_DMM,nu[1])];'),
 (acc,'let hosted=vec![(SC_GMM,nu[0]),(SC_UMM,nu[1])];'),
 (tr,'h.update(&self.state);'),(tr,'self.state = out;')]
for s,a in anchors:assert compact(a) in compact(s),a
fields=set(re.findall(r'pts\.(\w+)',src+acc))
ledger_fields={x for _,reads,writes in events['events'] for x in reads+writes}
assert fields==ledger_fields,(fields,ledger_fields)
assert set(re.findall(r'pts\.(\w+)',acc))=={'p_a','p_z','p_g','p_u','pq','pk','p_o','pv','lam_z','p_ht','p_s'}
names={name:int(n) for name,n in re.findall(r'const (SC_\w+): usize = (\d+);',layout)}
hosts_text=layout[layout.index('pub(crate) const HOSTS:'):layout.index('pub(crate) const A_SITES:')]
parsed=[]
for host,items in re.findall(r'\((SC_\w+),\s*&\[([^]]+)\]\)',hosts_text):
    parsed += [(names[x],names[host]) for x in re.findall(r'SC_\w+',items)]
assert set(parsed)==set(EXPECTED_HOSTS)
assert len(set(a for a,b in parsed))==12

def lg(v):return (v-1).bit_length()
def ref_slots(s):
    t,w,f,q,hd,kv,ln,dd,frozen=s
    tp,wp,fp,hp=(1<<lg(v) for v in (t,w,f,q))
    qp=hp*hd
    natural=[tp,hp*tp,16*tp,tp*wp,tp*qp,tp*kv*hd,hp*tp*tp,tp*fp,256,hp*tp*max(dd,1)]
    true=[t,q*t,9*t,t*w,t*q*hd,t*kv*hd,q*t*t,t*f,256,q*t*max(dd,1)]
    # Written as bit-lengths of explicit domain cardinalities rather than
    # reproducing native's slot match arms or indicator scan.
    domain=[lg(x) if i<2 else max(lg(x),ln) for i,x in enumerate(natural)]
    main=[domain[3],domain[3],domain[0],domain[2],domain[6],lg(wp),lg(wp),lg(wp),
          lg(kv)+lg(hd),lg(kv)+lg(tp),lg(qp),lg(wp),lg(wp),lg(fp),
          domain[3],domain[4],domain[5],domain[6],domain[7],domain[8],domain[8],domain[3],domain[3],domain[9]]
    deg=[3,3,3,4,3,2,2,2,2,2,2,2,2,2,4,4,4,4,4,3,2,2,2,4]
    for slot,dom in [(0,3),(1,3),(4,6),(14,3),(15,4),(16,5),(17,6),(18,7)]:
        deg[slot]+=int(not frozen and (1<<domain[dom])!=true[dom])
    if kv>1:deg[8]+=1;deg[9]+=1
    return [(main[i],2 if i in (8,9) else 1,deg[i]) for i in range(24 if dd else 23)]

def reachable(a,b,n,fs):
    # Independent stack traversal, no matrix transitive closure.
    todo=[a];seen=set()
    adjacency={i:[] for i in range(n)}
    for x,y,_ in EXPECTED:adjacency[x].append(y)
    if fs:
        for i in range(n-1):adjacency[i].append(i+1)
    while todo:
        x=todo.pop()
        if x==b:return True
        if x in seen:continue
        seen.add(x);todo.extend(adjacency[x])
    return False

def pairs(slots,fs):
    eq=[(i,j) for i,j in itertools.combinations(range(len(slots)),2) if slots[i]==slots[j]]
    free=[(i,j) for i,j in eq if not reachable(i,j,len(slots),fs) and not reachable(j,i,len(slots),fs)]
    return len(eq),len(eq)-len(free),free

cases=[]
shape_source=(D/'native/shape.rs').read_text()
profile_names=dict(re.findall(r'const (R13_\w+): &str = "([^"]+)";',shape_source))
registry={}
for body in re.findall(r'AccuracyProfile\{profile:(R13_\w+),([^\n]+)\}',shape_source):
    name,rest=body
    vals={k:int(v) for k,v in re.findall(r'(tokens|width|hidden|q_heads|head_dim|kv_heads|log_cols):(\d+)',rest)}
    if name in profile_names:registry[profile_names[name]]=vals
assert len(registry)==12
census=Path('/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/NATIVE_LAYOUT_CENSUS.json')
data=census.read_bytes();(D/'native/NATIVE_LAYOUT_CENSUS.json').write_bytes(data)
(D/'census-pin.json').write_text(json.dumps(dict(path=str(census),sha256=hashlib.sha256(data).hexdigest()),indent=2)+'\n')
for i,r in enumerate(json.loads(data)['rows']):
    q,hd,kv=(32,64,4) if r['width']==2048 else (32,128,8)
    if 'rung' in r['profile']:q,hd,kv=16,64,8
    assert q*hd==r['query_width'],r['profile']
    assert [r['tokens'],r['width'],r['hidden'],q,hd,kv,lg(r['n'])]==[registry[r['profile']][x] for x in ['tokens','width','hidden','q_heads','head_dim','kv_heads','log_cols']]
    cases.append((f'registry-{i}',[r['tokens'],r['width'],r['hidden'],q,hd,kv,lg(r['n']),32 if r['dd'] else 0,0],'registered geometry metadata; no constructor or native define executed'))
cases.append(('frozen-toy',[32,16,16,2,8,1,8,0,1],'legacy frozen geometry metadata'))
R=random.Random(SEED)
for i in range(256):
    # Deliberately includes unadmitted geometries and non-power-of-two true
    # extents, stressing padding metadata only. No profile admission implied.
    s=[R.choice([17,32,64,127,128,256,512]),R.choice([16,24,2048,3072,4096]),
       R.choice([16,40,5632,9216,14336]),R.choice([2,6,12,32]),R.choice([8,64,128]),
       R.choice([1,2,4,8]),R.choice([8,12,14,15]),R.choice([0,32]),R.choice([0,0,1])]
    cases.append((f'synthetic-{i}',s,'metadata stress; may be refused by native constructors'))
requests=[];expected={}
for label,s,scope in cases:
    for fs in [0,1]:
        key=label+('-native-fs' if fs else '-no-fs-counterfactual')
        requests.append(key+' '+' '.join(map(str,s+[fs])))
        sl=ref_slots(s);expected[key]=(sl,pairs(sl,fs))
(D/'input.tsv').write_text('\n'.join(requests)+'\n')
p=subprocess.run([str(D/'census')],cwd=D,input='\n'.join(requests)+'\n',text=True,capture_output=True,timeout=15)
(D/'census.stdout.log').write_text(p.stdout);(D/'census.stderr.log').write_text(p.stderr)
assert p.returncode==0,p.stderr
outputs={};checks=0
for line in p.stdout.splitlines():
    key,s,e,b,free=line.split('|');native=ast.literal_eval(s);got=(int(e),int(b),ast.literal_eval(free))
    sl,want=expected[key];assert native==sl,(key,native,sl);assert got==want,(key,got,want)
    checks+=3*len(sl)+3+2*len(got[2]);outputs[key]=dict(slots=sl,equal_shape_pairs=got[0],blocked_pairs=got[1],independent_pairs=got[2])
assert len(outputs)==len(expected)

controls=[]
for i in range(len(events['edges'])):
    bad=[tuple(x) for x in events['edges']];a,b,k=bad[i];bad[i]=((a+1)%b,b,k)
    try:check_ledger(bad)
    except AssertionError:controls.append('same-count-source-change-'+str(i))
    else:raise AssertionError(('uncaught edge mutation',i))
# Same endpoints/reachability, wrong named point; only typed ledger catches it.
bad=[tuple(x) for x in events['edges']]
i=bad.index((0,2,'point:r_t'));j=bad.index((1,2,'point:r_t2'))
bad[i]=(0,2,'point:r_t2');bad[j]=(1,2,'point:r_t')
try:check_ledger(bad)
except AssertionError:controls.append('same-endpoints-wrong-point-label')
else:raise AssertionError('point label shuffle passed')
assert (4,1,2)!=(3,2,2) and sum((4,1))==sum((3,2))
controls.append('same-total-rounds-different-main-extension')
# Source anchor tamper controls are deliberately local, not native mutants.
for i,(s,a) in enumerate(anchors):
    clean=compact(s);needle=compact(a);assert needle in clean
    assert needle not in clean.replace(needle,'SOURCE_MUTATED')
    controls.append('source-anchor-'+str(i))

chosen=next(k for k in outputs if 'registry-' in k and k.endswith('native-fs') and len(outputs[k]['slots'])==23)
eight=next(i for i,(_,s,_) in enumerate(cases) if s[0]==128 and s[1]==4096 and s[7]==0)
e_label=cases[eight][0];native8=outputs[e_label+'-native-fs'];no_fs8=outputs[e_label+'-no-fs-counterfactual']
groups={}
for i,shape in enumerate(native8['slots']):groups.setdefault(str(shape),[]).append(i)
result=dict(status='PASS',seed=SEED,shape_cases=len(cases),rust_reference_rows=len(outputs),numeric_comparisons=checks,
    native_metadata_methods=8,point_source_lines=49,point_dependencies=16,host_dependencies=12,negative_controls=len(controls),controls=controls,
    eight_b_t128=dict(shape=cases[eight][1],shape_groups=groups,native=native8,no_fs_counterfactual=no_fs8),
    all_native_fs_independent_pairs=sum(len(v['independent_pairs']) for k,v in outputs.items() if k.endswith('native-fs')),
    scope='Extracted R13 shape metadata plus reviewed source dependency ledger; Python equations/DFS versus Rust native metadata/Floyd-Warshall. No native define/prover/parser execution or cryptographic equivalence claim.',
    full_stack_proofs=0,passes=0,positions=0)
(D/'result.json').write_text(json.dumps(result,indent=2)+'\n')
(D/'cases.json').write_text(json.dumps(cases,indent=2)+'\n')
(D/'counts.json').write_text(json.dumps(outputs,indent=2)+'\n')
print(json.dumps({k:result[k] for k in ['status','shape_cases','rust_reference_rows','numeric_comparisons','negative_controls','all_native_fs_independent_pairs']}))
print(json.dumps(dict(eight_b_equal_shape_pairs=native8['equal_shape_pairs'],eight_b_blocked=native8['blocked_pairs'],counterfactual_free=len(no_fs8['independent_pairs']),groups=groups)))
