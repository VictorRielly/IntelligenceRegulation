#!/usr/bin/env python3
"""D helper pair streaming: exact arithmetic plus logical lifetime traces.

Only synthetic data. Logical coefficient-buffer words are not GPU registers,
physical peak memory, DRAM traffic, or an enclosing proving measurement.
"""
import collections
import hashlib
import importlib.util
import json
import os
import platform
import random
import resource
import signal
import sys
import time
from pathlib import Path

H = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('prior76', H/'prior-run.py')
prior = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prior)
from reference_math import P, Z, O, add, sub, mul, scale, fold, cube

SEED = 2026101978

class Node:
    def __init__(self, i, values):
        self.i, self.values = i, values

class Graph:
    """A straight-line sequence; public widths; no value-dependent branches."""
    def __init__(self):
        self.nodes = []

    def node(self, values, deps=(), label='literal', external=False):
        n = Node(len(self.nodes), list(values))
        self.nodes.append(dict(id=n.i, words=len(n.values), deps=[q.i for q in deps],
                               label=label, external=external))
        return n

    def op(self, name, fn, *xs, scalar=None, label=None):
        args = [q.values for q in xs]
        if scalar is not None:
            args.append(scalar)
        return self.node(fn(*args), xs, label or name)

    def lifetime(self, output):
        # Allocate a fresh output before releasing last-use inputs. No
        # in-place aliasing or allocator reuse is assumed. Primitive-internal
        # scalar temporaries are excluded in BOTH schedules.
        last = {n['id']: n['id'] for n in self.nodes}
        for n in self.nodes:
            for d in n['deps']:
                assert d < n['id']
                last[d] = n['id']
        last[output.i] = len(self.nodes)
        live = set()
        peak = 0
        peak_live = []
        den_peak = 0
        for n in self.nodes:
            live.add(n['id'])
            size = sum(self.nodes[j]['words'] for j in live if not self.nodes[j]['external'])
            den = sum(self.nodes[j]['words'] for j in live if self.nodes[j]['label']=='denominator')
            if size > peak:
                peak, peak_live = size, sorted(live)
            den_peak = max(den_peak, den)
            live = {j for j in live if last[j] > n['id']}
        return dict(peak_scratch_fp2_words=peak, denominator_peak_fp2_words=den_peak,
                    peak_live=peak_live, last_use=[last[j] for j in range(len(self.nodes))],
                    node_count=len(self.nodes), output=output.i)

def row(v, p, streamed, trace=False, wrong_pair=False):
    """Same D coefficients as prior.row; only denominator scheduling changes."""
    g = Graph()
    v = [g.node(x, label='original_endpoint_pair', external=True) for x in v]
    lit = g.node
    A = lambda a,b: g.op('add',prior.pa,a,b)
    S = lambda a,b: g.op('subtract',prior.ps,a,b)
    W = lambda a,w: g.op('extension_scale',prior.pw,a,scalar=w)
    B = lambda a,w: g.op('base_scale',prior.pb,a,scalar=w)
    M = lambda a,b: g.op('multiply',prior.pm,a,b)
    m,c,mu = p['m'],p['c'],p['mu']
    clauses = lit([p['const'],Z])
    for j,w in p['terms'].items():
        clauses = A(clauses,W(v[j],w))
    for j,k,w in p['bil']:
        clauses = A(clauses,W(M(v[j],v[k]),w))

    def denominator(k):
        j,a,off = p['ds'][k]
        out = S(lit([off]),B(v[j],a))
        g.nodes[out.i]['label'] = 'denominator'
        return out

    ds = None if streamed else [denominator(k) for k in range(len(p['ds']))]
    helpers = lit([Z])
    for k,hid in enumerate(p['hids']):
        ka = 2*k
        a = denominator(ka) if streamed else ds[ka]
        if ka+1 == len(p['ds']):
            rel = S(M(v[hid],a),lit([O]))
        else:
            kb = ka if wrong_pair else ka+1
            b = denominator(kb) if streamed else ds[kb]
            rel = S(M(M(v[hid],a),b),A(a,b))
        helpers = A(helpers,W(rel,mu[11+k]))

    supp = p['supp']
    if supp is not None:
        inner = lit([Z,Z])
        for j,w in p['pads']:
            inner = A(inner,W(v[j],w))
        pad = W(M(S(lit([O]),v[supp]),inner),mu[11+len(p['hids'])])
        helpers = A(helpers,pad)
        clauses = M(v[supp],clauses)
    out = M(v[m['eq']],A(helpers,clauses))
    for j,n,r,sh,half,nu in [(m['ha'],'A_AO','A_RAL',c[4],c[5],p['nu'][0]),
                              (m['hz'],'A_Z16','A_RDL',c[6],c[7],p['nu'][1])]:
        host = S(A(B(v[m[n]],sh),v[m[r]]),lit([(half,0)]))
        hv = M(v[j],host)
        if supp is not None:
            hv = M(hv,v[supp])
        out = A(out,W(hv,nu))
    assert len(out.values)==5
    return (out.values,g.nodes,g.lifetime(out)) if trace else out.values

def lazy_row(raw, p, lazy=True, trace=False, wrong_pair=False, memoize=True):
    """Same D coefficients as prior.row; only denominator scheduling changes."""
    g = Graph()
    class Endpoints:
        def __init__(self):
            self.cache={}; self.reads=0; self.differences=0; self.order=[]
        def __getitem__(self,j):
            if not memoize or j not in self.cache:
                lo,hi=raw[j]
                self.reads+=2; self.differences+=1; self.order.append(j)
                n=g.node([lo,prior.fs(hi,lo)],label='original_endpoint_pair',external=True)
                g.nodes[n.i]['source_index']=j
                # Subtraction needs lo,hi and its output simultaneously.
                # The node's two words represent lo and delta; charge hi too.
                g.nodes[n.i]['construction_transient_fp2_words']=1
                self.cache[j]=n
            return self.cache[j]
    v=Endpoints()
    if not lazy:
        for j in range(len(raw)):v[j]
    streamed=True
    lit = g.node
    A = lambda a,b: g.op('add',prior.pa,a,b)
    S = lambda a,b: g.op('subtract',prior.ps,a,b)
    W = lambda a,w: g.op('extension_scale',prior.pw,a,scalar=w)
    B = lambda a,w: g.op('base_scale',prior.pb,a,scalar=w)
    M = lambda a,b: g.op('multiply',prior.pm,a,b)
    m,c,mu = p['m'],p['c'],p['mu']
    clauses = lit([p['const'],Z])
    for j,w in p['terms'].items():
        clauses = A(clauses,W(v[j],w))
    for j,k,w in p['bil']:
        clauses = A(clauses,W(M(v[j],v[k]),w))

    def denominator(k):
        j,a,off = p['ds'][k]
        out = S(lit([off]),B(v[j],a))
        g.nodes[out.i]['label'] = 'denominator'
        return out

    ds = None if streamed else [denominator(k) for k in range(len(p['ds']))]
    helpers = lit([Z])
    for k,hid in enumerate(p['hids']):
        ka = 2*k
        a = denominator(ka) if streamed else ds[ka]
        if ka+1 == len(p['ds']):
            rel = S(M(v[hid],a),lit([O]))
        else:
            kb = ka if wrong_pair else ka+1
            b = denominator(kb) if streamed else ds[kb]
            rel = S(M(M(v[hid],a),b),A(a,b))
        helpers = A(helpers,W(rel,mu[11+k]))

    supp = p['supp']
    if supp is not None:
        inner = lit([Z,Z])
        for j,w in p['pads']:
            inner = A(inner,W(v[j],w))
        pad = W(M(S(lit([O]),v[supp]),inner),mu[11+len(p['hids'])])
        helpers = A(helpers,pad)
        clauses = M(v[supp],clauses)
    out = M(v[m['eq']],A(helpers,clauses))
    for j,n,r,sh,half,nu in [(m['ha'],'A_AO','A_RAL',c[4],c[5],p['nu'][0]),
                              (m['hz'],'A_Z16','A_RDL',c[6],c[7],p['nu'][1])]:
        host = S(A(B(v[m[n]],sh),v[m[r]]),lit([(half,0)]))
        hv = M(v[j],host)
        if supp is not None:
            hv = M(hv,v[supp])
        out = A(out,W(hv,nu))
    assert len(out.values)==5
    return (out.values,g.nodes,dict(reads=v.reads,differences=v.differences,order=v.order,output=out.i)) if trace else out.values

def independent_peak(nodes,output):
    """Reverse-suffix use census; does not consume Graph.last_use."""
    peak = den_peak = 0
    for t in range(len(nodes)):
        future_uses = {output}
        for later in nodes[t:]:
            future_uses.update(later['deps'])
        live = [n for n in nodes[:t] if n['id'] in future_uses]+[nodes[t]]
        peak=max(peak,sum(n['words'] for n in live if not n['external']))
        den_peak=max(den_peak,sum(n['words'] for n in live if n['label']=='denominator'))
    return peak,den_peak

def main():
    start=time.perf_counter()
    os.nice(19);cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    cat,native,compiler_argv=prior.native_library()
    rng=random.Random(SEED);rf=lambda:(rng.randrange(P),rng.randrange(P))
    profiles=json.loads((H/'reference/public-profile-scalars.json').read_text())
    desc=[(q['name'],4,32,q['public_scalars']) for q in profiles]
    desc += [('generic-four-top',4,31,profiles[0]['public_scalars']),
             ('generic-five-top',5,39,profiles[0]['public_scalars']),
             ('generic-odd-helper',4,32,profiles[0]['public_scalars'])]
    checks=collections.Counter();controls=collections.defaultdict(bool)
    census=[];traces=[];digest=hashlib.sha256()
    for name,ln,nw,sc in desc:
        m,lk,idx,h0,na=cat(ln,nw)
        assert lk==prior.old.reference_lookup(m,ln,nw)
        if name=='generic-odd-helper':lk=lk[:-1]
        nh=(len(lk)+1)//2
        c=[2*sc['norm_cn_a'],2*sc['norm_cn_m'],2**sc['norm_tn'],2**(sc['norm_tn']+1),
           2**sc['sh_ao'],2**(sc['sh_ao']-1),2**sc['sh_z'],2**(sc['sh_z']-1)]
        for padded in [False,True]:
            supp=h0+nh if padded else None;nt=h0+nh+int(padded);degree=5 if padded else 4
            mu=[rf() for _ in range(11+nh+int(padded))];nu=[rf(),rf()];zeta=rf()
            prior.reset();p=prior.plan(m,lk,list(range(h0,h0+nh)),mu,nu,c,ln,supp,zeta)
            prep=prior.COUNTS[:];rec=None
            for logn in [1,3,5]:
                N=1<<logn;tabs=[[rf() for _ in range(N)] for _ in range(nt)]
                tabs[5][0]=(P-1,P-1);tabs[6][0]=Z;tabs[7][0]=O
                original=[t[:] for t in tabs];rs=[rf() for _ in range(logn)];claim=None
                for ri,r in enumerate(rs):
                    half=len(tabs[0])//2;coeff=[Z]*5;baseline=[Z]*(degree+1)
                    for i in range(half):
                        v=[[t[i],sub(t[i+half],t[i])] for t in tabs]
                        prior.reset();want_coeff=prior.row(v,p);old_counts=prior.COUNTS[:]
                        prior.reset();bank,nodes0,life0=row(v,p,False,True);bank_counts=prior.COUNTS[:]
                        prior.reset();pair,nodes1,life1=row(v,p,True,True);pair_counts=prior.COUNTS[:]
                        assert pair==bank==want_coeff
                        assert pair_counts==bank_counts==old_counts
                        raw=[(t[i],t[i+half]) for t in tabs]
                        prior.reset();eager,en,el=lazy_row(raw,p,False,True);eager_counts=prior.COUNTS[:]
                        prior.reset();lazy,lnodes,lazy_io=lazy_row(raw,p,True,True);lazy_counts=prior.COUNTS[:]
                        assert lazy==eager==pair
                        assert lazy_counts==eager_counts==[old_counts[0],old_counts[1]+len(raw),old_counts[2],old_counts[3]]
                        assert el['reads']==lazy_io['reads']==2*len(raw)
                        assert el['differences']==lazy_io['differences']==len(raw)
                        prior.reset();zv,zt,zl=lazy_row([(Z,Z) for _ in raw],p,True,True)
                        assert prior.COUNTS==lazy_counts and zt==lnodes and zl==lazy_io
                        checks['lazy_coefficients']+=5;checks['charged_endpoint_censuses']+=1
                        checks['lazy_value_independent_traces']+=1
                        prior.reset();bad,bn,bl=lazy_row(raw,p,True,True,memoize=False);no_memo_counts=prior.COUNTS[:]
                        assert bad==lazy
                        controls['no_memoization_adds_reads'] |= bl['reads']>lazy_io['reads']

                        checks['row_coefficients']+=5;checks['equal_operation_censuses']+=1
                        prior.reset();zero,zn,zlife=row([[Z,Z] for _ in tabs],p,True,True)
                        assert prior.COUNTS==pair_counts and zlife==life1 and zn==nodes1
                        checks['value_independent_traces']+=1
                        if rec is None:
                            for nn,ll in [(nodes0,life0),(nodes1,life1)]:
                                assert independent_peak(nn,ll['output'])==(
                                    ll['peak_scratch_fp2_words'],ll['denominator_peak_fp2_words'])
                                checks['independent_lifetime_audits']+=1
                            assert life1['peak_scratch_fp2_words']<life0['peak_scratch_fp2_words']
                            assert life1['denominator_peak_fp2_words']<=4
                            rec=dict(descriptor=name,ln=ln,norm_w=nw,padded=padded,N_examples=[2,8,32],
                                     tables=nt,lookups=len(lk),helpers=nh,degree=degree,prep=prep,
                                     row_operations=pair_counts,
                                     bank_peak_words=life0['peak_scratch_fp2_words'],
                                     pair_peak_words=life1['peak_scratch_fp2_words'],
                                     bank_denominator_words=life0['denominator_peak_fp2_words'],
                                     pair_denominator_words=life1['denominator_peak_fp2_words'],
                                     common_endpoint_words=2*nt,common_round_accumulator_words=5,
                                     added_full_tables=0,removed_original_tables=0,
                                     coefficient_bytes_per_fp2=16,
                                     node_count=[len(nodes0),len(nodes1)])
                            traces.append(dict(descriptor=name,padded=padded,bank=nodes0,pair=nodes1,
                                               bank_lifetime=life0,pair_lifetime=life1,eager=en,lazy=lnodes,eager_io=el,lazy_io=lazy_io,no_memo_io=bl,no_memo_operations=no_memo_counts))
                        for j,x in enumerate(pair):coeff[j]=add(coeff[j],x)
                        for t in range(degree+1):
                            values=[add(x[0],scale(x[1],t)) for x in v]
                            nv,_=native(values,m,lk,idx,h0,ln,mu,nu,c,supp,zeta)
                            independent=prior.old.full(values,prior.old.independent_clauses(values,m,mu,c,ln),
                                                       m,lk,h0,mu,nu,c,supp,zeta)
                            assert prior.ev(pair,(t,0))==nv==independent
                            baseline[t]=add(baseline[t],nv);checks['native_grid_values']+=1
                            digest.update(str(nv).encode())
                        q=rf();values=[add(x[0],mul(q,x[1])) for x in v]
                        nv,_=native(values,m,lk,idx,h0,ln,mu,nu,c,supp,zeta)
                        assert prior.ev(pair,q)==nv;checks['native_offgrid_values']+=1
                        controls['wrong_pair'] |= row(v,p,True,wrong_pair=True)!=pair
                        controls['drop_high_degree'] |= prior.ev(pair[:-1],q)!=nv
                    assert prior.convert(coeff,degree,ri>0,claim)==baseline
                    checks['round_messages']+=1
                    if claim is not None:
                        assert add(baseline[0],baseline[1])==claim
                        controls['stale_recovered_claim'] |= prior.convert(coeff,degree,True,add(claim,O))!=baseline
                    claim=prior.ev(coeff,r);tabs=fold(tabs,r)
                finals=[t[0] for t in tabs];assert finals==[cube(t,rs) for t in original]
                assert native(finals,m,lk,idx,h0,ln,mu,nu,c,supp,zeta)[0]==claim
                checks['original_finals']+=nt;checks['final_relations']+=1
                # All public role ids, helper ids and support remap together.
                v=[[t[0],sub(t[N//2],t[0])] for t in original];a=row(v,p,True)
                perm=list(range(nt));rng.shuffle(perm);pv=[None]*nt
                for j,x in enumerate(v):pv[perm[j]]=x
                mm={n:perm[j] for n,j in m.items()}
                pp=prior.plan(mm,[(perm[j],w,d) for j,w,d in lk],[perm[h0+k] for k in range(nh)],mu,nu,c,ln,
                              None if supp is None else perm[supp],zeta,[perm[j] for j in range(5,m['d'])])
                assert row(pv,pp,True)==a
                praw=[(x[0],add(x[0],x[1])) for x in pv]
                assert lazy_row(praw,pp)==a;checks['permutations']+=1
                am=m.copy();am['A_AO']=am['A_X']
                ap=prior.plan(am,lk,list(range(h0,h0+nh)),mu,nu,c,ln,supp,zeta)
                assert row(v,ap,True)==prior.row(v,ap)
                assert lazy_row([(x[0],add(x[0],x[1])) for x in v],ap)==prior.row(v,ap);checks['aliases']+=1
                stale=mu[:];stale[0]=add(stale[0],O)
                sp=prior.plan(m,lk,list(range(h0,h0+nh)),stale,nu,c,ln,supp,zeta)
                controls['stale_mu'] |= row(v,sp,True)!=a
                hp=prior.plan(m,list(reversed(lk)),list(range(h0,h0+nh)),mu,nu,c,ln,supp,zeta)
                controls['helper_order'] |= row(v,hp,True)!=a
                if padded:
                    np=prior.plan(m,lk,list(range(h0,h0+nh)),mu,nu,c,ln,None,zeta)
                    controls['omit_support'] |= row(v,np,True)!=a
                controls['wrong_msb'] |= logn>1 and cube(original[5],rs)!=cube(original[5],list(reversed(rs)))
                checks['fixtures']+=1
            census.append(rec)
    assert len(controls)==8 and all(controls.values()),controls
    (H/'traces.json').write_text(json.dumps(traces,indent=2)+'\n')
    result=dict(status='PASS',run_id='20261019T101854Z-3562a78f',seed=SEED,checks=checks,
                controls=controls,census=census,synthetic_digest=digest.hexdigest(),
                wall_seconds=time.perf_counter()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                compiler_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
                cpu_affinity=[cpu],threads=1,platform=platform.platform(),compiler_argv=compiler_argv,
                logical_lifetime_model='See independent audit: every original endpoint plus one high-value transient per construction, derived polynomial buffers and five-word round accumulator. Excludes primitive-internal scratch, plan, physical registers and enclosing tables/proof.',
                limits='59s CPU/wall,512MiB address space,one nice19 CPU; noGPU/Cargo/install',
                scope='Synthetic complete-D polynomial and original finals; actual captured Rust body/catalog with exact u128 field and Shape/Layout substitutes. No native proof/RNG/transcript/masks/privacy/device throughput.')
    (H/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='census'},indent=2))
    print(json.dumps(census[2],indent=2))

if __name__=='__main__':main()
