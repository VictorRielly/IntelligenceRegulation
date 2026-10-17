#!/usr/bin/env python3
"""Source-derived public lifetime oracle. Synthetic data; no native proof."""
import functools
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import random
import re
import resource
import signal
import struct
import time

HERE = Path(__file__).resolve().parent
SEED = 2026100418
RUN = '20261004T000146Z-b9833e6d'
P = 2**64 - 2**32 + 1
DOMS = ['L', 'D', 'F', 'Q', 'Kv', 'S']
STAGES = ['A_COPY', 'U8_HIST', 'EXP_HIST', 'ACT_HIST', 'A_COMMIT',
          'M_COMMIT', 'H_ALLOC'] + ['H_'+d for d in DOMS] + ['H_EXP', 'H_ACT', 'TABLES', 'H_COMMIT', 'SLOTS', 'OPEN']


def pad(x):
    return 1 << (x-1).bit_length()


def parse_planes(text, ln, ls, lp):
    constants = {k:int(v) for k,v in re.findall(r'const (A_\w+|LN_TOY|LS_TOY|LP_TOY): usize = (\d+);', text)}
    section = text.split('let segs:')[-1].split('let mut map')[0]
    segs = re.findall(r'\((A_\w+), (\d+|LN_TOY|LS_TOY|LP_TOY), (\d+|ln|ls|lp), Dom::(\w+)\)', section)
    assert len(segs) == 18
    names_by_toy = {v:k for k,v in constants.items() if k.startswith('A_')}
    names, domains, idmap, groups = [], [], {}, {}
    env = dict(ln=ln,ls=ls,lp=lp)
    for first, old_len, new_len, dom in segs:
        start = constants[first]
        old = int(old_len) if old_len.isdigit() else constants[old_len]
        count = int(new_len) if new_len.isdigit() else env[new_len]
        base = len(names)
        for k in range(old):
            if start+k in names_by_toy:
                idmap[names_by_toy[start+k]] = base+k
        # Names for additional limbs have no toy constant.
        for k in range(count):
            if new_len in env:
                names.append(first.replace('0',str(k)) if k < old else first+'+'+str(k))
            else:
                names.append(names_by_toy.get(start+k, first+'+'+str(k)))
            domains.append(dom)
        if new_len in env:
            groups[dict(A_NR0='nr',A_NS0='ns',A_MR0='mr',A_MS0='ms',A_PL0='pl',A_SR0='sr',A_SG0='sg')[first]] = list(range(base,base+count))
    return names, domains, idmap, groups


def source_lks(text, ids, groups, ln, ls, lp, norm_wrho, wrho_s):
    """Recognize a deliberately small grammar; never eval source text."""
    body = text.split('pub(crate) fn lookups_at(')[1].split('/// (first H helper')[0]
    scales = dict(norm_scale=1 << (8*ln-norm_wrho), sigma_scale=1 << (8*ls-wrho_s), p_scale=128)
    out, dom, conditional = {d:[] for d in DOMS}, None, False
    call = re.compile(r'(byte|sym|scaled)\(ids\.(?:at\((A_\w+)\)|(nr|ns|mr|ms|pl|sr|sg)\(([^)]*)\))(?:, (\w+))?\)')
    for rawline in body.splitlines():
        line = rawline.split('//')[0].strip()
        match = re.match(r'Dom::(\w+) => \{', line)
        if match:
            dom = match[1]
            continue
        if line == 'if norm_top {':
            conditional = True
            continue
        if line == '}':
            conditional = False
            continue
        if not line.startswith('v.'):
            continue
        assert dom in out, line
        if conditional and norm_wrho == 8*ln:
            continue
        matches = list(call.finditer(line))
        assert matches, ('unrecognized lookup', line)
        for match in matches:
            kind, name, group, arg, scale = match.groups()
            if name:
                planes = [ids[name]]
            elif arg == 'k':
                assert '(0..' in line
                planes = groups[group]
            else:
                assert arg in ['ln - 1','ls - 1','lp - 1'], arg
                planes = [groups[group][-1]]
            for plane in planes:
                if kind == 'sym':
                    out[dom] += [(plane,1,127),(plane,-1,127)]
                else:
                    coefficient = (int(scale) if scale.isdigit() else scales[scale]) if kind == 'scaled' else 1
                    out[dom].append((plane,coefficient,0))
    return out


def named_reference(ln, ls, lp, norm_wrho, wrho_s):
    """Independent named catalog transcribed from relation plane families."""
    v = {d:[] for d in DOMS}
    def byte(dom,*names):
        v[dom].extend((name,1,0) for name in names)
    def scale(dom,name,c):
        v[dom].append((name,c,0))
    def sym(dom,name):
        v[dom].extend([(name,1,127),(name,-1,127)])
    def limb_names(first,count,toy):
        return [first.replace('0',str(k)) if k < toy else first+'+'+str(k) for k in range(count)]
    byte('L','A_LIMB','A_LIMBM')
    byte('D','A_XL0','A_XL1'); sym('D','A_Y')
    for group in ['A_NR0','A_NS0']:
        ns=limb_names(group,ln,4); byte('D',*ns)
        if norm_wrho != 8*ln: scale('D',ns[-1],2**(8*ln-norm_wrho))
    byte('D','A_AL0','A_AL1','A_RAL'); scale('D','A_RAL',2); byte('D','A_X1L0','A_X1L1'); sym('D','A_YM')
    for group in ['A_MR0','A_MS0']:
        ns=limb_names(group,ln,4); byte('D',*ns)
        if norm_wrho != 8*ln: scale('D',ns[-1],2**(8*ln-norm_wrho))
    byte('D','A_X2L0','A_X2L1','A_ZL0','A_ZL1','A_RDL'); scale('D','A_RDL',4)
    byte('F','A_RGL'); scale('F','A_RGL',2); byte('F','A_UL0','A_UL1','A_HL0','A_HL1','A_RH0','A_RH1'); scale('F','A_RH1',4)
    for name,rem in [('A_Q8','A_RQL'),('A_QR8','A_RQRL')]:
        sym('Q',name); byte('Q',rem); scale('Q',rem,2)
    sym('Q','A_O8'); byte('Q','A_RO0','A_RO1'); scale('Q','A_RO1',128)
    for name,rem in [('A_K8','A_RKL'),('A_V8','A_RVL'),('A_KR8','A_RKRL')]:
        sym('Kv',name); byte('Kv',rem); scale('Kv',rem,2)
    sym('S','A_S8'); byte('S','A_RSL'); scale('S','A_RSL',4)
    for group,count,toy,c in [('A_PL0',lp,2,128),('A_SR0',ls,2,2**(8*ls-wrho_s)),('A_SG0',ls,2,2**(8*ls-wrho_s))]:
        ns=limb_names(group,count,toy); byte('S',*ns); scale('S',ns[-1],c)
    return v


def last_reads(names,lks):
    last = {k:0 for k in range(len(names)-3)}
    byname = {n:k for k,n in enumerate(names)}
    for d in DOMS:
        for p,_,_ in lks[d]: last[p] = STAGES.index('H_'+d)
    for name in ['A_S8','A_MX','A_E']: last[byname[name]] = STAGES.index('H_EXP')
    for name in ['A_G8','A_A16']: last[byname[name]] = STAGES.index('H_ACT')
    return last


def add(a,b): return ((a[0]+b[0])%P,(a[1]+b[1])%P)
def neg(a): return ((-a[0])%P,(-a[1])%P)
def mul(a,b): return ((a[0]*b[0]+7*a[1]*b[1])%P,(a[0]*b[1]+a[1]*b[0])%P)
def inverse(a):
    if a == (0,0): raise ValueError('zero LogUp denominator; discard attempt')
    n=pow((a[0]*a[0]-7*a[1]*a[1])%P,P-2,P)
    return (a[0]*n%P,-a[1]*n%P)


@functools.lru_cache(maxsize=12000)
def inverse_ref(a):
    if a == (0,0): raise ValueError('zero LogUp denominator; discard attempt')
    def product(x,y):
        t=[0,0,0]
        for i in range(2):
            for j in range(2): t[i+j]+=x[i]*y[j]
        return ((t[0]+7*t[2])%P,t[1]%P)
    n=P*P-2; result=(1,0)
    while n:
        if n&1: result=product(result,a)
        a=product(a,a); n//=2
    return result


class ReleasedRead(Exception): pass


def prep(raw,names,domains,lks,tp,alpha,beta,release=False,last=None,reference=False,skip_tables=False):
    store={p:list(v) for p,v in raw.items()}; trace=[]; phases=[]; idx={n:k for k,n in enumerate(names)}
    invert=inverse_ref if reference else inverse
    gu8,gexp,gact=(11,2),(13,3),(17,5)
    exp=[512-i for i in range(256)]; act=[i*3-384 for i in range(256)]
    def read(p,i,phase):
        if p not in store: raise ReleasedRead((phase,names[p],i))
        trace.append((phase,p,i)); return store[p][i]
    def affine(p,k,c,i,phase):
        z=c+k*read(p,i,phase)
        if reference: return (z+2**63)%2**64-2**63
        z &= 2**64-1
        return z if z < 2**63 else z-2**64
    def delta(i,phase):
        ht,j=divmod(i,tp)
        s=read(idx['A_S8'],i,phase) if j <= ht%tp else -127
        return (read(idx['A_MX'],ht,phase)-s+2**63)%2**64-2**63
    def den(i,x,tag): return add(alpha,neg(add(add((i%P,0),mul(beta,(x%P,0))),tag)))
    def end(phase):
        phases.append(phase)
        if release:
            for p in list(store):
                if last[p] == STAGES.index(phase): del store[p]
    a=[]
    for p in raw:
        a.extend(read(p,i,'A_COPY')%P for i in range(len(raw[p])))
    end('A_COPY')
    hist=[0]*256
    for d in DOMS:
        for p,k,c in lks[d]:
            for i in range(len(raw[p])):
                x=affine(p,k,c,i,'U8_HIST'); hist[x if 0<=x<256 else 0]+=1
    end('U8_HIST')
    me,ma=[0]*256,[0]*256
    for i in range(len(raw[idx['A_E']])):
        z=delta(i,'EXP_HIST'); x=read(idx['A_E'],i,'EXP_HIST')
        me[z if 0<=z<256 and exp[z]==x else 0]+=1
    end('EXP_HIST')
    for i in range(len(raw[idx['A_A16']])):
        z=read(idx['A_G8'],i,'ACT_HIST')+128; x=read(idx['A_A16'],i,'ACT_HIST')
        ma[z if 0<=z<256 and act[z]==x else 0]+=1
    end('ACT_HIST')
    for phase in ['A_COMMIT','M_COMMIT','H_ALLOC']: end(phase)
    h=[]
    for d in DOMS:
        phase='H_'+d; cols=lks[d]
        for k in range(0,len(cols),2):
            col=[]
            for i in range(len(raw[cols[k][0]])):
                v=(0,0)
                for p,c,z in cols[k:k+2]:
                    x=affine(p,c,z,i,phase); v=add(v,invert(add(alpha,neg(add((x%P,0),gu8)))))
                col.append(v)
            h.append(col)
        end(phase)
    h.append([invert(den(delta(i,'H_EXP'),read(idx['A_E'],i,'H_EXP'),gexp)) for i in range(len(raw[idx['A_E']]))]); end('H_EXP')
    h.append([invert(den(read(idx['A_G8'],i,'H_ACT')+128,read(idx['A_A16'],i,'H_ACT'),gact)) for i in range(len(raw[idx['A_A16']]))]); end('H_ACT')
    for tag,table,m,byte in [(gu8,list(range(256)),hist,True),(gexp,exp,me,False),(gact,act,ma,False)]:
        col=[]
        for i,x in enumerate(table):
            if skip_tables and m[i]==0: col.append((0,0)); continue
            q=add(alpha,neg(add((i,0),tag))) if byte else den(i,x,tag)
            z=invert(q); col.append((z[0]*m[i]%P,z[1]*m[i]%P))
        h.append(col)
    end('TABLES')
    for phase in ['H_COMMIT','SLOTS','OPEN']: end(phase)
    words=[v for col in h for limb in [0,1] for pair in col for v in [pair[limb]]]
    return a,hist,me,ma,words,trace,phases


def type_widths(ln,ls,lp):
    return ([4,8,4,8]+[1,8]+[1,1]+[2,1,1,1]+[1]*(2*ln)+[2,1,1,1,2,1,1,1]+[1]*(2*ln)+[2,2,1,1,1,1,1]+[1]*7+[1]*6+[1,1,1,8,2]+[1]*(lp+2*ls)+[1,1,2,2,1,1,2,1,1,1,1]+[8]*3)


def ledger(text):
    out=[]
    for name,t,d,f,h,kv,dh,lc,ln,ls,wrho in [('toy',32,16,16,2,1,8,8,4,2,29),('m125',512,768,2048,12,4,64,14,4,3,32),('llama3_8b_T512',512,4096,14336,32,8,128,14,5,3,34),('llama3_8b_T1024',1024,4096,14336,32,8,128,14,5,3,34),('llama3_8b_T2048',2048,4096,14336,32,8,128,14,5,3,34)]:
        n=2**lc; nn=4*n; q=256; lp=2
        names,ds,ids,groups=parse_planes(text,ln,ls,lp)
        lks=source_lks(text,ids,groups,ln,ls,lp,wrho,math.ceil(math.log2(t))+9)
        last=last_reads(names,lks); widths=type_widths(ln,ls,lp)
        sizes=dict(T=pad(t),Ht=pad(h)*pad(t),L=max(16*pad(t),n),D=max(pad(t)*pad(d),n),Q=max(pad(t)*pad(h)*dh,n),Kv=max(pad(t)*kv*dh,n),S=max(pad(h)*pad(t)**2,n),F=max(pad(t)*pad(f),n),Tab=max(256,n))
        r=lambda dom:max(1,sizes[dom]//n)
        helpers={dom:(len(lks[dom])+1)//2 for dom in DOMS}
        counts={dom:ds.count(dom) for dom in set(ds)}
        sites=sum([1,1,22,2,2,7,2,2,counts['D']+2,counts['Q']+1,counts['Kv']+1,counts['S']+2,counts['F'],3,1,1])
        ar=sum(r(dom) for dom in ds)+2*sites+2
        hr=2*(sum(helpers[dom]*r(dom) for dom in DOMS)+r('S')+r('F')+4*r('Tab'))+2*(sum(helpers.values())+6)+2
        if name=='m125': assert (ar,hr)==(5681,7120),(ar,hr)
        raw=sum(sizes[dom]*8 for dom in ds[:-3]); typed=sum(sizes[dom]*w for dom,w in zip(ds[:-3],widths[:-3]))
        looked=sum(sizes[dom]*len(lks[dom])*8 for dom in DOMS); indices=(sizes['S']+sizes['F'])*8
        # Named-store lower-bound ledger: raw A/H, A pads/tree/salts, one helper Vec.
        # CPU arm additionally retains full A codewords. M/IO/weights/pools unknown.
        phases={}
        for strategy,typed_on,release in [('production_materialized',False,False),('raw_lazy',False,False),('raw_lazy_release',False,True),('typed_lazy',True,False),('typed_lazy_release',True,True)]:
            rows=[]
            ws=[sizes[dom]*(widths[k] if typed_on else 8) for k,dom in enumerate(ds[:-3])]
            for si,stage in enumerate(STAGES):
                transient=sum(w for k,w in enumerate(ws) if (not release and si<=STAGES.index('H_ACT')) or (release and si<=last[k]))
                if strategy=='production_materialized' and si>=1 and si<=STAGES.index('H_ACT'): transient+=looked
                if strategy=='production_materialized' and si>=STAGES.index('ACT_HIST') and si<=STAGES.index('H_ACT'): transient+=indices
                common=ar*n*8
                if si>=STAGES.index('A_COMMIT'): common+=ar*q*8+nn*32+(2*nn-1)*32
                if si>=STAGES.index('H_ALLOC'): common+=hr*n*8
                helper=16*max(sizes.values()) if stage.startswith('H_') and stage not in ['H_ALLOC','H_COMMIT'] else 0
                rows.append(dict(phase=stage,witness_and_preparation_bytes=transient,named_common_bytes=common,helper_vec_upper_bytes=helper,chunked_host_named_bytes=common+transient+helper,cpu_A_codeword_named_bytes=common+transient+helper+(ar*nn*8 if si>=STAGES.index('A_COMMIT') else 0)))
            packing=raw+typed if typed_on else raw
            for tier in ['chunked_host_named_bytes','cpu_A_codeword_named_bytes']:
                maximum=max(rows,key=lambda z:z[tier]); phases[strategy+'_'+tier]=dict(maximum_bytes=max(packing,maximum[tier]),maximum_phase='PACK' if packing>maximum[tier] else maximum['phase'],pack_overlap_bytes=packing,rows=rows)
        release_bytes={stage:sum(ws for p,ws in enumerate([sizes[dom]*8 for dom in ds[:-3]]) if STAGES[last[p]]==stage) for stage in STAGES}
        out.append(dict(name=name,context=t,registered=name in ['toy','m125'],norm_limbs=ln,builder_refuses=ln!=4,A_rows=ar,H_rows=hr,raw_bytes=raw,typed_bytes=typed,lookup_bytes=looked,index_bytes=indices,release_after_phase_raw_bytes=release_bytes,phases=phases,limits='Named host payload maximum, not actual peak. Excludes M, IO/boundaries, weights, encoded H, runtime/pools, scratch, receipts, allocator. CPU A-codeword arm is partial, not complete CPU peak. 8B shapes are unregistered count-only.'))
    return out


def main():
    resource.setrlimit(resource.RLIMIT_AS,(512<<20,512<<20)); resource.setrlimit(resource.RLIMIT_CPU,(55,55))
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))}); signal.alarm(59)
    start=time.perf_counter(); snap=HERE/'snapshots'
    layout=(snap/'ops__zkp-mvp__sonnet-hardening__hashline__src__private_block__layout.rs').read_text()
    protocol=(snap/'ops__zkp-mvp__sonnet-hardening__hashline__src__private_block__protocol.rs').read_text()
    order=re.search(r'const LOOKUP_DOMS: \[Dom; 6\] = \[([^]]+)\]',layout)[1]
    assert re.findall(r'Dom::(\w+)',order)==DOMS
    assert protocol.index('drop(wit);')>protocol.index('let act_den =')
    assert 'data: [a.data.as_slice(), h.data.as_slice()' in protocol
    rng=random.Random(SEED); cases=[]; negatives=[]; comparisons=0; lks_compared=0
    for ln,ls,wrho in [(4,2,29),(4,3,32),(5,3,34),(5,4,40)]:
        names,ds,ids,groups=parse_planes(layout,ln,ls,2)
        lks=source_lks(layout,ids,groups,ln,ls,2,wrho,8*ls-3)
        ref=named_reference(ln,ls,2,wrho,8*ls-3)
        for dom in DOMS:
            assert [(names[p],k,c) for p,k,c in lks[dom]]==ref[dom],dom
        lks_compared+=sum(map(len,lks.values()))
        named_last={n:'A_COPY' for n in names[:-3]}
        for dom in DOMS:
            for name,_,_ in ref[dom]: named_last[name]='H_'+dom
        named_last.update({n:'H_EXP' for n in ['A_S8','A_MX','A_E']}); named_last.update({n:'H_ACT' for n in ['A_G8','A_A16']})
        last=last_reads(names,lks)
        assert {names[k]:STAGES[v] for k,v in last.items()}==named_last
        for t,heads in [(1,1),(3,3),(5,1)]:
            tp=pad(t); hp=pad(heads)
            sizes=dict(T=tp,Ht=hp*tp,L=16*tp,D=tp*8,Q=tp*hp*4,Kv=tp*4,S=hp*tp*tp,F=tp*8)
            raw={k:[rng.randrange(-127,256) for _ in range(sizes[dom])] for k,dom in enumerate(ds[:-3])}
            # Include full i64 wrapping on a looked limb and a late nonzero E.
            raw[ids['A_RAL']][0]=2**63-1; raw[ids['A_E']][0]=512
            raw[ids['A_G8']][0]=-128; raw[ids['A_A16']][0]=-384
            alpha,beta=(1234567,89),(0,0) if t==1 else (97,53)
            full=prep(raw,names,ds,lks,tp,alpha,beta,reference=True)
            released=prep(raw,names,ds,lks,tp,alpha,beta,release=True,last=last)
            assert full==released
            comparisons+=len(full[0])+len(full[4]); cases.append(dict(ln=ln,ls=ls,norm_wrho=wrho,context=t,heads=heads,trace_reads=len(full[5]),field_words=len(full[0])+len(full[4]),value_sha256=hashlib.sha256(b''.join(struct.pack('<Q',v) for v in full[0]+full[4])).hexdigest()))
            if t==3 and ln==4 and ls==2:
                for target in ['A_XL0','A_MX','A_E','A_G8','A_A16']:
                    bad=dict(last); bad[ids[target]]=0
                    try: prep(raw,names,ds,lks,tp,alpha,beta,release=True,last=bad)
                    except ReleasedRead: negatives.append('early_release_'+target)
                    else: raise AssertionError(target)
                rev={d:list(reversed(v)) for d,v in lks.items()}
                assert prep(raw,names,ds,rev,tp,alpha,beta)[4]!=full[4]; negatives.append('reordered_lookup_columns')
                ref_trace=list(full[5]); ref_trace[0]=(ref_trace[0][0],ref_trace[0][1],1)
                assert ref_trace!=released[5]; negatives.append('wrong_read_index')
                # An unused public byte-table denominator is still mandatory.
                # Choose value outside all looked values of this fixture.
                used=set()
                for dom in DOMS:
                    for p,k,c in lks[dom]: used.update((k*x+c+2**63)%2**64-2**63 for x in raw[p])
                unused=next(i for i in range(256) if i not in used)
                zero_alpha=((unused+11)%P,2)
                for do_release in [False,True]:
                    try: prep(raw,names,ds,lks,tp,zero_alpha,beta,release=do_release,last=last)
                    except ValueError as e: assert str(e)=='zero LogUp denominator; discard attempt'; negatives.append('unused_table_zero_'+str(do_release))
                    else: raise AssertionError('unused table skipped')
                prep(raw,names,ds,lks,tp,zero_alpha,beta,skip_tables=True)
                negatives.append('skip_zero_multiplicity_table_changes_refusal')
    accounting=ledger(layout)
    prior=json.loads((snap/'research__zkp-efficiency__experiments__typed-witness-readers-20261003__result.json').read_text())['layout_ledger']
    for row in accounting:
        old=next(z for z in prior if z['name']==row['name'])
        assert (row['raw_bytes'],row['typed_bytes'],row['lookup_bytes']+row['index_bytes'])==(old['witness_raw_bytes'],old['witness_typed_bytes'],old['lookup_i64_bytes']+old['index_i64_bytes'])
    elapsed=time.perf_counter()-start
    result=dict(status='passed',run_identity=RUN,seed=SEED,cases=cases,case_count=len(cases),lookup_specs_compared=lks_compared,field_words_compared=comparisons,negative_controls=negatives,lookup_domain_order=DOMS,stages=STAGES,ledger=accounting,elapsed_s=elapsed,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,python=platform.python_version(),cpu=next(l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),device='CPU only',estimated_memory_mib=64,script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),scope='Source-derived full Lk/Ids and synthetic read/preparation oracle; no native Layout execution, full block, mask/RNG/PCS or proof',full_stack=dict(countable_tokens=0,passes=0,context_length=None,steady_tokens_per_s=None,total_tokens_per_s=None,startup_fraction=None,witness_s=None,proof_s=None,serialization_s=None,verification_s=None,proof_lag_s=None,pipeline_drain_s=None))
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ['ledger','cases']},indent=2))


if __name__=='__main__': main()
