"""Independent restricted interpreter of pinned native lookup descriptors.
Reuses previously reviewed local source parser; no candidate imports.
"""
from pathlib import Path
import ast,re
HERE=Path(__file__).resolve().parent
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

source=(HERE/'source/layout.rs').read_text()
shape=(HERE/'source/shape.rs').read_text()
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

P=2**64-2**32+1
def accepts(expressions, residue):
    return all((e['cst']+sum(c*residue for _,c in e['terms']))%P in range(256) for e in expressions)

def allowed_residues(expressions):
    # Every present family contains byte(x) or x+127. Enumerate that table
    # then independently intersect all original affine table memberships.
    first=expressions[0];((_,c),)=first['terms'];assert c in (-1,1)
    candidates=[((v-first['cst'])*c)%P for v in range(256)]
    return set(x for x in candidates if accepts(expressions,x))
