"""Independent restricted-source interpreter and tuple-field MSB audit.

No Rust, downloaded code, imports of candidate E or candidate MLE/ledger math.
Native symbolic Ids access is retained by name, not guessed numeric plane ID.
"""
from pathlib import Path
import ast,copy,hashlib,json,re,resource,time
from reference import add,sub,mul

HERE=Path(__file__).resolve().parent;t0=time.monotonic();checks=0
def check(x):
    global checks
    checks+=1
    if not x: raise AssertionError(checks)
def digest(x):return hashlib.sha256(json.dumps(x,sort_keys=True,separators=(',',':')).encode()).hexdigest()
def close(s,i,left='(',right=')'):
    depth=0
    for j in range(i,len(s)):
        if s[j]==left:depth+=1
        if s[j]==right:
            depth-=1
            if depth==0:return j
    raise ValueError('unbalanced')
def split(s):
    out=[];start=0;depth=0
    for i,c in enumerate(s):
        if c in '([{':depth+=1
        if c in ')]}':depth-=1
        if c==',' and depth==0:out.append(s[start:i].strip());start=i+1
    out.append(s[start:].strip());return [x for x in out if x]

source=(HERE/'source/hashline__src__private_block__layout.rs').read_text()
shape=(HERE/'source/hashline__src__private_block__shape.rs').read_text()
frozen=shape.split('pub(crate) const FROZEN: NormCalibration = NormCalibration {',1)[1].split('};',1)[0]
cal={k:int(v) for k,v in re.findall(r'(sh_\w+): (\d+)',frozen)}
f_p=int(re.search(r'pub\(crate\) const F_P: u32 = (\d+);',source)[1])

def scalar(s,env):
    s=s.strip().replace('1i64','1').replace(' as u32','')
    for k,v in cal.items():s=s.replace('sh.'+k,str(v))
    s=s.replace('sh.norm_wrho','32').replace('sh.wrho_s',str(env['w']))
    s=s.replace('F_P',str(f_p))
    s=s.replace('ids.ln','ln').replace('ids.ls','ls').replace('ids.lp','lp')
    tree=ast.parse(s,mode='eval')
    def walk(n):
        if isinstance(n,ast.Constant) and type(n.value)==int:return n.value
        if isinstance(n,ast.Name) and n.id in env:return env[n.id]
        if isinstance(n,ast.UnaryOp) and isinstance(n.op,ast.USub):return -walk(n.operand)
        if isinstance(n,ast.BinOp):
            a,b=walk(n.left),walk(n.right)
            if isinstance(n.op,ast.Add):return a+b
            if isinstance(n.op,ast.Sub):return a-b
            if isinstance(n.op,ast.Mult):return a*b
            if isinstance(n.op,ast.LShift):return a<<b
        if isinstance(n,ast.Call) and isinstance(n.func,ast.Name) and n.func.id in ('one','two'):
            return 1<<((8 if n.func.id=='one' else 16)-walk(n.args[0]))
        raise ValueError(('unsupported scalar',s,ast.dump(n)))
    return walk(tree.body)

def native_expressions(T,dd):
    text=re.sub(r'//[^\n]*','',source)
    i=text.index('pub(crate) fn lookups_at(')
    start=text.index('{',i);body=text[start+1:close(text,start,'{','}')]
    w=T.bit_length()-1+9
    env={'ln':4,'ls':(w+7)//8,'lp':2,'w':w}
    for name in ('norm_scale','sigma_scale','p_scale'):
        rhs=re.search(r'let '+name+r' = ([^;]+);',body)[1]
        env[name]=scalar(rhs,env)
    def plane(s,scope):
        if m:=re.fullmatch(r'ids.at\((A_\w+)\)',s):return m[1]
        if m:=re.fullmatch(r'ids\.(\w+)\((.+)\)',s):return m[1]+':'+str(scalar(m[2],scope))
        raise ValueError(('unsupported plane',s))
    def item(s,scope):
        name,rest=s.split('(',1);args=split(rest[:-1]);p=plane(args[0],scope)
        if name=='byte':return [{'terms':[[p,1]],'cst':0}]
        if name=='scaled':return [{'terms':[[p,scalar(args[1],scope)]],'cst':0}]
        if name=='sym':return [{'terms':[[p,1]],'cst':127},{'terms':[[p,-1]],'cst':127}]
        raise ValueError(('unsupported item',name))
    def extend(s,scope):
        s=s.strip()
        if s.startswith('['):return sum((item(x,scope) for x in split(s[1:-1])),[])
        if m:=re.fullmatch(r'\(0\.\.(\w+)\)\.map\(\|k\| (.*)\)',s,re.S):
            return sum((item(m[2],dict(scope,k=k)) for k in range(scope[m[1]])),[])
        return item(s,scope)
    def statements(s):
        out=[];cursor=0
        while cursor<len(s):
            m=re.search(r'v\.(push|extend)\(|if (norm_top|sh.dd_cap == 0)\s*\{',s[cursor:])
            if not m:break
            begin=cursor+m.start();endstart=cursor+m.end()
            if m[2]:
                j=close(s,endstart-1,'{','}')
                enabled=False if m[2]=='norm_top' else not dd
                if enabled:out.extend(statements(s[endstart:j]))
            else:
                j=close(s,endstart-1);out.extend(extend(s[endstart:j],env))
            cursor=j+1
        return out
    out={}
    for d in ('L','D','Q','Kv','F','S','Dd'):
        m=re.search(r'Dom::'+d+r'(?: if sh.dd_cap > 0)? => \{',body)
        j=close(body,m.end()-1,'{','}')
        out[d]=[] if d=='Dd' and not dd else statements(body[m.end():j])
    return out

def msb_fold(v,p):
    v=list(v)
    for r in p:
        mid=len(v)//2
        v=[add(v[j],mul(r,sub(v[j+mid],v[j]))) for j in range(mid)]
    check(len(v)==1)
    return v[0]

# Re-read every original and copied source, before testing any hypothesis.
pins=json.loads((HERE/'source-pins.json').read_text())
for pin in pins:
    check(hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'])
    check(hashlib.sha256((HERE/pin['snapshot']).read_bytes()).hexdigest()==pin['sha256'])

# Import only candidate descriptor outputs for comparison; field and mapping
# calculations above remain independent.
from ledger import lookups,columns
fixtures=json.loads((HERE/'inputs.json').read_text());descriptor_cases=0
for f in fixtures:
    actual=native_expressions(f['T'],f['dd']);expected=lookups(f['T'],f['dd'])
    check(actual==expected);descriptor_cases+=sum(map(len,actual.values()))
    check(sum(map(len,actual.values()))==len(f['sizes'])-1)
    # Shape::lookups_per_position is a separately stated count oracle.
    ls=(f['T'].bit_length()-1+9+7)//8
    counts={'L':2,'D':34,'Q':13,'Kv':12,'F':9,'S':4 if f['dd'] else 7+2*(ls+1),'Dd':3+2*(ls+1) if f['dd'] else 0}
    check({d:len(v) for d,v in actual.items()}==counts)

# A count-preserving change to the pinned native descriptor must be visible.
# No production file is changed; only this interpreter's in-memory input.
original_source=source;source_mutations=0
for before,after in [
    ('v.push(byte(ids.at(A_LIMB)))','v.push(byte(ids.at(A_LIMBM)))'),
    ('scaled(ids.at(A_RO1), two(sh.sh_o))','scaled(ids.at(A_RO1), two(sh.sh_h))'),
    ('v.extend(sym(ids.at(A_Q8)))','v.extend(sym(ids.at(A_K8)))')]:
    check(before in original_source)
    source=original_source.replace(before,after,1)
    changed=native_expressions(128,False);normal=lookups(128,False)
    check(sum(map(len,changed.values()))==sum(map(len,normal.values())))
    check(changed!=normal);source_mutations+=1
source=original_source

for s in json.loads((HERE/'site-summary.json').read_text()):
    f=next(f for f in fixtures if all(f[k]==s[k] for k in ('model','T','dd')))
    heights=[n.bit_length()-1 for n in f['sizes']]
    check(s['tree_layers']==sum(heights))
    check(s['all_semantic_terminals']==4*sum(heights))
    check(s['private_semantic_terminals']==sum(4*h-2 for h in heights))
    check(s['unmerged_original_A_leaf_obligations']==2*len(heights))
    for k in (13,14,15):
        check(s['conditional_private_pair_payload_by_log_cols'][str(k)]==sum(4*h-2 for h in heights)*(2**k)*16)
    for k in ('actual_new_private_claim_sites','actual_extension_rounds','actual_CFS_coefficients','actual_PCS_groups','native_net_memory_saving_bytes','native_time_saving_s'):
        check(s[k] is None)
    if s['model']=='8B' and s['T'] in (128,512):
        ledger=json.loads((HERE/('ledger-8B-T%d-%s.json'%(s['T'],'DD' if s['dd'] else 'nonDD'))).read_text())
        check(digest(ledger)==s['ledger_sha256'])
        cols=columns(f);cursor=0
        for col,h in zip(cols,heights):
            expr=({'plane':'A_MU8'} if col['domain']=='Tab' else native_expressions(f['T'],f['dd'])[col['domain']][col['ordinal']])
            for depth in range(1,h+1):
                for b in (0,1):
                    for component in ('N','D'):
                        x=ledger[cursor];cursor+=1
                        check((x['column'],x['domain'],x['ordinal'],x['expression_hash'],x['depth'],x['branch'],x['component'])==(col['column'],col['domain'],col['ordinal'],digest(expr),depth,b,component))
        check(cursor==len(ledger))

saved=json.loads((HERE/'fixtures.json').read_text());mle_cases=0
for f in saved:
    rho=[tuple(x) for x in f['rho_lsb']];eta=tuple(f['eta'])
    for b in (0,1):
        point=list(reversed(rho))+[(b,0)]
        for c in (0,1):
            value=msb_fold([tuple(x[c]) for x in f['child']],point)
            check(value==tuple(f['finals'][2*b+c]));mle_cases+=1
    for c in (0,1):
        check(msb_fold([tuple(x[c]) for x in f['child']],list(reversed(rho))+[eta])==tuple(f['merged'][c]));mle_cases+=1

original_link_cases=0
for f in json.loads((HERE/'original-links.json').read_text()):
    expr=native_expressions(f['T'],f['dd'])[f['domain']][f['ordinal']]
    check(digest(expr)==f['expression_hash'])
    plane_evals={name:msb_fold([tuple(x) for x in v],[tuple(x) for x in f['point_msb']]) for name,v in f['planes'].items()}
    value=sub(sub(tuple(f['alpha']),tuple(f['g'])),(expr['cst'],0))
    for name,coef in expr['terms']:value=sub(value,mul((coef,0),plane_evals[name]))
    check(value==tuple(f['denominator']));original_link_cases+=1

result={'status':'PASS','checks':checks,'verified_source_pins':len(pins),
    'native_source_descriptor_cases':descriptor_cases,'independent_MSB_cases':mle_cases,
    'count_preserving_native_descriptor_mutations':source_mutations,
    'independent_tiny_original_A_expression_links':original_link_cases,
    'elapsed_s':time.monotonic()-t0,'maxrss_KiB':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    'scope':'Independent restricted-source descriptor interpreter, tuple MSB half-fold and symbolic row budget; not native claims or private proof.'}
(HERE/'validation-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
