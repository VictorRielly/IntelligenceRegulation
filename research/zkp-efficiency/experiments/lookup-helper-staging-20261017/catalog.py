import ast,re
DOMS=['L','D','F','Q','Kv','S']

def split_args(s):
    out, start, depth = [], 0, 0
    for i, c in enumerate(s):
        depth += (c in '([') - (c in ')]')
        if c == ',' and depth == 0:
            out.append(s[start:i].strip()); start = i + 1
    if s[start:].strip(): out.append(s[start:].strip())
    return out

def scalar(expr, env):
    expr = expr.strip().replace('1i64', '1')
    if expr.startswith('one('): return 1 << (8 - env[expr[4:-1]])
    if expr.startswith('two('): return 1 << (16 - env[expr[4:-1]])
    for k in sorted(env, key=len, reverse=True): expr = expr.replace(k, str(env[k]))
    tree = ast.parse(expr, mode='eval')
    def rec(n):
        if isinstance(n, ast.Constant) and type(n.value) is int: return n.value
        if isinstance(n, ast.BinOp):
            a, b = rec(n.left), rec(n.right)
            if isinstance(n.op, ast.Sub): return a - b
            if isinstance(n.op, ast.LShift): return a << b
        raise ValueError('unsupported scalar: ' + expr)
    return rec(tree.body)

def source_catalog(text, ln, ls, lp, norm_w, soft_w, shifts):
    """Restricted fail-closed recognizer of current Rust constructor grammar."""
    body = text.split('pub(crate) fn lookups_at(')[1].split('\n    v\n}')[0]
    arms = re.findall(r'Dom::(\w+) => \{(.*?)\n        \}', body, re.S)
    assert [d for d, _ in arms] == DOMS
    env = dict(ln=ln, ls=ls, lp=lp, norm_scale=1 << (8*ln-norm_w),
               sigma_scale=1 << (8*ls-soft_w), p_scale=1 << (8*lp-10))
    env.update({'sh.'+k: v for k, v in shifts.items()})
    def plane(s, k=None):
        m = re.fullmatch(r'ids\.at\((A_\w+)\)', s)
        if m: return m[1]
        m = re.fullmatch(r'ids\.(nr|ns|mr|ms|pl|sr|sg)\((.*)\)', s)
        assert m, s
        ix = k if m[2] == 'k' else scalar(m[2], env)
        return m[1]+str(ix)
    def expr(s):
        if s.startswith('sym('):
            p = plane(s[4:-1]); return [([(p,1)],127), ([(p,-1)],127)]
        if s.startswith('byte('): return [([(plane(s[5:-1]),1)],0)]
        assert s.startswith('scaled('), s
        p, c = split_args(s[7:-1]); return [([(plane(p),scalar(c,env))],0)]
    out = {}
    for dom, arm in arms:
        lines = [l.split('//')[0].strip() for l in arm.splitlines()]
        cols, condition = [], False
        for line in lines:
            if not line: continue
            if line == 'if norm_top {': condition=True; continue
            if line == '}': condition=False; continue
            if condition and norm_w == 8*ln: continue
            m = re.fullmatch(r'v\.extend\(\(0\.\.(ln|ls|lp)\)\.map\(\|k\| byte\((.*?)\)\)\);', line)
            if m:
                cols.extend([([(plane(m[2],k),1)],0) for k in range(env[m[1]])]); continue
            m = re.fullmatch(r'v\.(push|extend)\((.*)\);',line)
            assert m, line
            s = m[2]
            if s.startswith('['):
                for item in split_args(s[1:-1]): cols.extend(expr(item))
            else: cols.extend(expr(s))
        out[dom]=cols
    return out

def reference_catalog(ln,ls,lp,norm_w,soft_w,s):
    """Independently specified semantic families, no Rust parser calls."""
    def b(p): return ([(p,1)],0)
    def sc(p,c): return ([(p,c)],0)
    def sy(p): return [([(p,1)],127), ([(p,-1)],127)]
    def limbs(p,n): return [b(p+str(k)) for k in range(n)]
    d=[b('A_XL0'),b('A_XL1')]+sy('A_Y')
    for pre in ['nr','ns']:
        d+=limbs(pre,ln)
        if norm_w<8*ln: d+=[sc(pre+str(ln-1),1 << (8*ln-norm_w))]
    d += [b('A_AL0'),b('A_AL1'),b('A_RAL'),sc('A_RAL',1 << (8-s['sh_ao'])),b('A_X1L0'),b('A_X1L1')]+sy('A_YM')
    for pre in ['mr','ms']:
        d+=limbs(pre,ln)
        if norm_w<8*ln: d+=[sc(pre+str(ln-1),1 << (8*ln-norm_w))]
    d += [b('A_X2L0'),b('A_X2L1'),b('A_ZL0'),b('A_ZL1'),b('A_RDL'),sc('A_RDL',1 << (8-s['sh_z']))]
    f=[b('A_RGL'),sc('A_RGL',1 << (8-s['sh_g']))]+[b(p) for p in ['A_UL0','A_UL1','A_HL0','A_HL1','A_RH0','A_RH1']]+[sc('A_RH1',1 << (16-s['sh_h']))]
    q=sy('A_Q8')+[b('A_RQL'),sc('A_RQL',1 << (8-s['sh_qkv']))]+sy('A_QR8')+[b('A_RQRL'),sc('A_RQRL',2)]+sy('A_O8')+[b('A_RO0'),b('A_RO1'),sc('A_RO1',1 << (16-s['sh_o']))]
    kv=[]
    for p,r in [('A_K8','A_RKL'),('A_V8','A_RVL')]: kv+=sy(p)+[b(r),sc(r,1 << (8-s['sh_qkv']))]
    kv+=sy('A_KR8')+[b('A_RKRL'),sc('A_RKRL',2)]
    z=sy('A_S8')+[b('A_RSL'),sc('A_RSL',1 << (8-s['sh_s']))]+limbs('pl',lp)+[sc('pl'+str(lp-1),1 << (8*lp-10))]
    for pre in ['sr','sg']: z+=limbs(pre,ls)+[sc(pre+str(ls-1),1 << (8*ls-soft_w))]
    return dict(L=[b('A_LIMB'),b('A_LIMBM')],D=d,F=f,Q=q,Kv=kv,S=z)
