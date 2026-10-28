"""Lexical allocation census, NOT a Rust compiler or runtime call trace."""
import hashlib, json, pathlib, re, time, resource, os
HERE=pathlib.Path(__file__).resolve().parent
ROOT=HERE.parents[3]
OUT=HERE/'source'
OUT.mkdir(exist_ok=True)
def clean(src):
    # Preserve offsets/newlines. Rust raw strings and nested block comments supported.
    out=list(src); i=0; depth=0
    while i<len(src):
        start=i
        if src.startswith('//',i):
            end=src.find('\n',i); end=len(src) if end<0 else end
        elif src.startswith('/*',i):
            end=i+2; depth=1
            while end<len(src) and depth:
                if src.startswith('/*',end): depth+=1; end+=2
                elif src.startswith('*/',end): depth-=1; end+=2
                else: end+=1
            assert depth==0
        elif src[i]=="'" and re.match(r"'(?:\\(?:u\{[0-9a-fA-F_]+\}|x[0-9a-fA-F]{2}|.)|[^\\'\n])'",src[i:]):
            end=i+re.match(r"'(?:\\(?:u\{[0-9a-fA-F_]+\}|x[0-9a-fA-F]{2}|.)|[^\\'\n])'",src[i:]).end()
        elif src[i]=='"' or (src[i]=='r' and re.match(r'r#*"',src[i:])):
            m=re.match(r'r(#+)?"',src[i:]) if src[i]=='r' else None
            if m:
                mark='"'+(m.group(1) or ''); end=src.find(mark,i+m.end())
                assert end>=0; end+=len(mark)
            else:
                end=i+1
                while end<len(src):
                    if src[end]=='\\': end+=2
                    elif src[end]=='"': end+=1; break
                    else: end+=1
        else:
            i+=1; continue
        for j in range(start,end):
            if out[j]!='\n': out[j]=' '
        i=end
    return ''.join(out)

def functions(src):
    code=clean(src); rows=[]
    for m in re.finditer(r'\bfn\s+(\w+)\s*(?:<[^{};]*>)?\s*\(',code):
        # Array types such as &[u8; 32] contain semicolons inside arguments.
        cursor=m.end(); par=1; square=0; start=-1
        while cursor<len(code):
            c=code[cursor]
            if c=='(': par+=1
            elif c==')': par-=1
            elif c=='[': square+=1
            elif c==']': square-=1
            elif par==0 and square==0 and c=='{': start=cursor; break
            elif par==0 and square==0 and c==';': break
            cursor+=1
        if start<0: continue
        depth=1; end=start+1
        while depth and end<len(code):
            depth+=(code[end]=='{')-(code[end]=='}'); end+=1
        if depth: raise ValueError('unbalanced Rust function')
        rows.append(dict(name=m.group(1),start=m.start(),body=start,end=end,line=src.count('\n',0,m.start())+1))
    return code,rows

PAT=re.compile(r'\b(?:(?:dev|self\.dev)\s*\.\s*(alloc(?:_zeros)?)(?:\s*::\s*<\s*(u32|u64)\s*>)?\s*\(|(?:dev|self\.dev)\s*\.\s*(htod_sync_copy)\s*\(|Pooled\s*::\s*(take(?:_min)?)\s*\(|cu\s*::\s*(malloc_host)\s*\()')
def scan(src):
    code,fs=functions(src); items=[]
    for m in PAT.finditer(code):
        owner=[f for f in fs if f['body']<m.start()<f['end']]
        f=min(owner,key=lambda x:x['end']-x['start']) if owner else dict(name='<none>',line=0)
        end=m.end(); depth=1
        while depth:
            if end>=len(code): raise ValueError('call unbalanced')
            depth+=(code[end]=='(')-(code[end]==')'); end+=1
        kind='pooled-request' if m.group(4) else 'host-pinned' if m.group(5) else 'device-raw'
        if f['name'] in ['pool_take','pool_take_min']: kind='pool-backing'
        items.append(dict(line=src.count('\n',0,m.start())+1,function=f['name'],function_line=f['line'],kind=kind,operation=next(x for x in [m.group(1),m.group(3),m.group(4),m.group(5)] if x),dtype=m.group(2),args=' '.join(src[m.end():end-1].split()),statement=src.splitlines()[src.count('\n',0,m.start())].strip()))
    return items

def main():
    t=time.perf_counter()
    trees={'r8':ROOT/'results/zk60_1b_native_20261017/r8/frozen-tree/hashline/src','gpu':ROOT/'ops/zkp-mvp/gpu-zerocheck/hashline/src','root':ROOT/'hashline/src'}
    result={'scope':'lexical allocation sites only; no execution/reachability/peak inferred','trees':{},'callers':[]}
    manifest=[]
    for label,tree in trees.items():
        p=tree/'gpu/cuda.rs'; b=p.read_bytes(); s=b.decode(); name=label+'__cuda.rs'
        (OUT/name).write_bytes(b); items=scan(s)
        result['trees'][label]=dict(path=str(p),snapshot=name,sha256=hashlib.sha256(b).hexdigest(),sites=items)
        manifest.append(dict(path=str(p),snapshot=name,sha256=hashlib.sha256(b).hexdigest()))
        for p in sorted(tree.rglob('*.rs')):
            if p.name=='cuda.rs': continue
            s=p.read_text()
            try: code,fs=functions(s)
            except ValueError as e: raise ValueError(str(p)+': '+str(e))
            for sym in ['dev_pool_drain','dev_reserve_hard','dev_reserve']:
                for m in re.finditer(r'\b'+sym+r'\s*\(',code):
                    if re.search(r'\bfn\s+$',code[max(0,m.start()-10):m.start()]): continue
                    owner=[f for f in fs if f['body']<m.start()<f['end']]
                    f=min(owner,key=lambda x:x['end']-x['start']) if owner else dict(name='<none>')
                    result['callers'].append(dict(tree=label,path=str(p.relative_to(tree)),line=s.count('\n',0,m.start())+1,symbol=sym,function=f['name'],test_named='test' in str(p.relative_to(tree))))
        # Snapshot only public code used by the manually reviewed call chain.
        for rel in ['pcs.rs','gpu/mod.rs','private_block/protocol.rs','private_block/run.rs','private_block/argument.rs','gpu/fzc.rs']:
            p=tree/rel
            if p.exists():
                b=p.read_bytes(); name=label+'__'+rel.replace('/','__'); (OUT/name).write_bytes(b)
                manifest.append(dict(path=str(p),snapshot=name,sha256=hashlib.sha256(b).hexdigest()))
    (HERE/'census.json').write_text(json.dumps(result,indent=2)+'\n')
    (HERE/'source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    r=dict(status='GENERATED',sites={k:len(v['sites']) for k,v in result['trees'].items()},callers=len(result['callers']),wall_seconds=time.perf_counter()-t,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=len(list(pathlib.Path('/proc/self/task').iterdir())),affinity=sorted(os.sched_getaffinity(0)))
    (HERE/'census-result.json').write_text(json.dumps(r,indent=2)+'\n'); print(json.dumps(r))
if __name__=='__main__': main()
