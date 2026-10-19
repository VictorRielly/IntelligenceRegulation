#!/usr/bin/env python3
"""Real public D catalog, synthetic Fp2 differential; no proof or GPU job."""
import ctypes,hashlib,json,math,os,platform,random,resource,signal,subprocess,time
from pathlib import Path
from prepare import generate
from reference_math import *
H=Path(__file__).resolve().parent
SEED=2026101875
MAX=2**64-1

def semantic_bind(ln):
    # Independent plane sequence, not the native segment-table loop.
    groups=[['A_X','A_XL0','A_XL1','A_Y'],['nr'+str(i) for i in range(ln)],['ns'+str(i) for i in range(ln)],
      ['A_AO','A_AL0','A_AL1','A_RAL','A_X1','A_X1L0','A_X1L1','A_YM'],['mr'+str(i) for i in range(ln)],['ms'+str(i) for i in range(ln)],
      ['A_Z16','A_X2','A_X2L0','A_X2L1','A_ZL0','A_ZL1','A_RDL']]
    names=sum(groups,[]);return {p:5+i for i,p in enumerate(names)}

def bind(ln,raw,consts):
    a_count=raw[0]-5;idx=raw[1:82];ns=raw[82];shaped=raw[83:83+ns];at=83+ns;nlk=raw[at];lk=[]
    for j in range(nlk):
        p,c,d=raw[at+1+3*j:at+4+3*j];lk.append((shaped[p],ctypes.c_int64(c).value,ctypes.c_int64(d).value))
    m={p:idx[q] for p,q in consts.items() if p.startswith('A_') and 8<=q<=42}
    for group in ['nr','ns','mr','ms']:
        start=consts['A_'+group.upper()+'0'];plane0=next(p for p,i in enumerate(shaped) if i==idx[start])
        for j in range(ln):m[group+str(j)]=shaped[plane0+j]
    m.update(ga=3,gm=4,d=raw[0],dm=raw[0]+1)
    for name,ix in semantic_bind(ln).items():assert m[name]==ix,(name,m[name],ix)
    return m,lk,idx,raw[0]+2,a_count

def prep(m,mu,c,ln):
    # Accumulate coefficients by returned table id, including collisions.
    terms={}
    def put(name,a):
        j=m[name];terms[j]=add(terms.get(j,Z),a)
    for name,a in [('A_X',sub(mu[2],mu[5])),('A_AO',sub(mu[3],mu[5])),('A_X1',sub(add(mu[4],mu[5]),mu[9])),('A_X2',add(mu[8],mu[9])),('A_Z16',sub(mu[10],mu[9])),('d',sub(scale(mu[0],c[2]),scale(mu[1],c[3]))),('dm',sub(scale(mu[6],c[2]),scale(mu[7],c[3])))]:put(name,a)
    for name,k in [('A_XL0',2),('A_AL0',3),('A_X1L0',4),('A_X2L0',8),('A_ZL0',10)]:
        put(name,sub(Z,mu[k]));put(name[:-1]+'1',sub(Z,scale(mu[k],256)))
    for pre,a in [('nr',sub(mu[1],mu[0])),('ns',mu[1]),('mr',sub(mu[7],mu[6])),('ms',mu[7])]:
        for k in range(ln):put(pre+str(k),scale(a,256**k))
    const=add(scale(sm(mu[i] for i in [2,3,4,8,10]),32768),add(mu[1],mu[7]))
    bil=[(m['ga'],m['A_X'],scale(mu[0],c[0])),(m['d'],m['A_Y'],sub(Z,scale(mu[0],c[3]))),(m['gm'],m['A_X1'],scale(mu[6],c[1])),(m['dm'],m['A_YM'],sub(Z,scale(mu[6],c[3])))]
    return terms,const,bil

def lin(v,p):return add(p[1],sm(mul(a,v[j]) for j,a in p[0].items()))
def fast(v,l,p):return add(l,sm(mul(a,mul(v[j],v[k])) for j,k,a in p[2]))

def independent_clauses(v,m,mu,c,ln):
    # Earlier independent eleven equations use logical toy indices only.
    z=[Z]*64
    consts=json.loads((H/'constants.json').read_text())
    for n,j in consts.items():
        if n in m and 8<=j<=42:z[j]=v[m[n]]
    for j,n in [(3,'ga'),(4,'gm'),(43,'d'),(44,'dm')]:z[j]=v[m[n]]
    for group,ix in zip(['nr','ns','mr','ms'],maps(ln)):
        for k,j in enumerate(ix):z[j]=v[m[group+str(k)]]
    return clauses(z,mu,c,ln)

def extra(v,m,lk,h0,mu,nu,c,supp,zeta):
    ds=[sub((101,3),add((d+19,0),scale(v[j],a))) for j,a,d in lk]
    rel=[]
    for k in range((len(lk)+1)//2):
        a=ds[2*k];b=ds[2*k+1] if 2*k+1<len(ds) else None
        rel.append(mul(mu[11+k],sub(mul(v[h0+k],a),O) if b is None else sub(mul(mul(v[h0+k],a),b),add(a,b))))
    if supp is not None:
        weight=O;pad=[]
        for j in range(5,m['d']):pad.append(mul(weight,v[j]));weight=mul(weight,zeta)
        rel.append(mul(mu[11+(len(lk)+1)//2],mul(sub(O,v[supp]),sm(pad))))
    g=O if supp is None else v[supp]
    hw=sub(add(scale(v[m['A_AO']],c[4]),v[m['A_RAL']]),(c[5],0))
    hd=sub(add(scale(v[m['A_Z16']],c[6]),v[m['A_RDL']]),(c[7],0))
    host=add(mul(mul(mul(nu[0],v[1]),g),hw),mul(mul(mul(nu[1],v[2]),g),hd))
    return sm(rel),host,g

def full(v,cl,m,lk,h0,mu,nu,c,supp,zeta):
    ex,host,g=extra(v,m,lk,h0,mu,nu,c,supp,zeta)
    return add(mul(v[0],add(ex,mul(g,cl))),host)

def main():
    start=time.perf_counter();os.nice(19);cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2);resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    argv=generate();cp=subprocess.run(argv,cwd=H,capture_output=True,text=True,timeout=25);(H/'compile.log').write_text(cp.stdout+cp.stderr);assert cp.returncode==0,cp.stderr
    import re
    consts={n:int(i) for n,i in re.findall(r'pub\(crate\) const (A_\w+): usize = (\d+);',(H/'native/hashline__src__private_block__layout.rs').read_text())}
    (H/'constants.json').write_text(json.dumps(consts,indent=2)+'\n')
    U=ctypes.c_uint64;I=ctypes.c_int64;S=ctypes.c_size_t;ptr=ctypes.POINTER(U)
    lib=ctypes.CDLL(str(H/'isolated.so'));lib.catalog.argtypes=[S,ctypes.c_uint32,S,ctypes.c_uint32,ctypes.c_uint32,ctypes.POINTER(S)];lib.catalog.restype=S
    lib.original.argtypes=[ptr,S,ptr,S,ptr,ptr,ctypes.POINTER(S),ctypes.POINTER(S),ctypes.POINTER(S),ctypes.POINTER(I),S,ptr,ptr]
    def cat(ln,nw):
        out=(S*1024)();n=lib.catalog(ln,nw,3,3,4,out);return bind(ln,list(out[:n]),consts)
    def native(v,m,lk,idx,h0,ln,mu,nu,c,supp,zeta):
        vs=(U*(2*len(v)))(*(a for q in v for a in q));ms=(U*(2*len(mu)))(*(a for q in mu for a in q));nus=(U*4)(*(a for q in nu for a in q));cs=(U*8)(*c);ip=(S*81)(*idx)
        sp=(S*7)(m['ga'],m['gm'],m['d'],m['dm'],h0,ln,MAX if supp is None else supp)
        wp=(S*(4*ln))(*(m[g+str(k)] for g in ['nr','ns','mr','ms'] for k in range(ln)));lks=(I*(3*len(lk)))(*(a for q in lk for a in q));zp=(U*2)(*zeta);out=(U*2)()
        lib.original(vs,len(v),ms,len(mu),nus,cs,ip,sp,wp,lks,len(lk),zp,out);return tuple(out)
    rng=random.Random(SEED);rf=lambda:(rng.randrange(P),rng.randrange(P));checks=dict(fixtures=0,native_full_values=0,original_final_values=0,round_sums=0,permuted_values=0,aliased_values=0,refusals=0)
    controls={n:False for n in ['toy_index_fails','changed_helper_order','drop_helper_column','stale_mu','wrong_msb','missing_original_final','alias_overwrite','support_omission','bad_binding_refused']};census=[];digest=hashlib.sha256()
    profiles=json.loads((H/'public-profile-scalars.json').read_text())
    descriptors=[]
    for p in profiles:
        sc=p['public_scalars'];w=(sc['norm_tn']+1+math.isqrt(sc['norm_ceps']+p['width']*32767**2).bit_length());assert w==32
        descriptors.append((p['name'],4,w,sc))
    descriptors.extend([('generic-four-top',4,31,profiles[0]['public_scalars']),('generic-five-top',5,39,profiles[0]['public_scalars'])])
    for name,ln,nw,sc in descriptors:
      m,lk,idx,h0,na=cat(ln,nw);nh=(len(lk)+1)//2;base_nt=h0+nh
      c=[2*sc['norm_cn_a'],2*sc['norm_cn_m'],2**sc['norm_tn'],2**(sc['norm_tn']+1),2**sc['sh_ao'],2**(sc['sh_ao']-1),2**sc['sh_z'],2**(sc['sh_z']-1)]
      original_reads=set(range(base_nt));helpers={j for j,a,d in lk}|set(range(h0,base_nt));hosts={1,2,m['A_AO'],m['A_RAL'],m['A_Z16'],m['A_RDL']};bil={m[n] for n in ['ga','gm','d','dm','A_X','A_X1','A_Y','A_YM']}
      for padded in [False,True]:
        supp=base_nt if padded else None;nt=base_nt+int(padded);remaining={0}|helpers|hosts|bil
        if padded:remaining|=set(range(5,m['d']))|{supp}
        removed=set(range(nt))-remaining
        census.append({'descriptor':name,'ln':ln,'norm_w':nw,'padded_D':padded,'A_columns':na,'lookup_descriptors':len(lk),'helpers':nh,'original_tables':nt,'candidate_original_online_tables':len(remaining),'candidate_online_with_L':len(remaining)+1,'omittable_online_original_tables':sorted(removed),'omittable_names':[n for n,j in m.items() if j in removed],'original_private_finals':na+2+nh,'removable_original_fold_tables':0,'generic_driver_extra_tables':1,'linear_build_sources':17+4*ln})
        for logn in [1,3,5]:
          N=1<<logn;mu=[rf() for _ in range(11+nh+int(padded))];nu=[rf(),rf()];zeta=rf();p=prep(m,mu,c,ln)
          tabs=[[rf() for _ in range(N)] for _ in range(nt)];ls=[lin([t[i] for t in tabs],p) for i in range(N)];original=[t[:] for t in tabs];rs=[rf() for _ in range(logn)]
          for r in rs:
            h=len(ls)//2
            for d in [Z,O,(2,0),(4,0),rf()]:
              totals=[Z,Z]
              for i in range(h):
                v=[add(t[i],mul(d,sub(t[i+h],t[i]))) for t in tabs];lv=add(ls[i],mul(d,sub(ls[i+h],ls[i])));cl=independent_clauses(v,m,mu,c,ln);got=fast(v,lv,p);assert got==cl
                want=full(v,cl,m,lk,h0,mu,nu,c,supp,zeta);nv=native(v,m,lk,idx,h0,ln,mu,nu,c,supp,zeta);assert want==nv==full(v,got,m,lk,h0,mu,nu,c,supp,zeta)
                checks['native_full_values']+=1;totals=[add(totals[0],nv),add(totals[1],want)];digest.update(str(nv).encode())
              assert totals[0]==totals[1];checks['round_sums']+=1
            tabs=fold(tabs,r);ls=fold([ls],r)[0]
          v=[t[0] for t in tabs];assert v==[cube(t,rs) for t in original];checks['original_final_values']+=nt
          # Public table permutations: remap every role, coefficients and data.
          perm=list(range(nt));rng.shuffle(perm);vm=[Z]*nt
          for j,q in enumerate(v):vm[perm[j]]=q
          mm={n:perm[j] for n,j in m.items()};pp=prep(mm,mu,c,ln);assert fast(vm,lin(vm,pp),pp)==independent_clauses(vm,mm,mu,c,ln);checks['permuted_values']+=1
          # Synthetic aliases test coefficient accumulation, not native layout admission.
          am=m.copy();am['A_AO']=am['A_X'];ap=prep(am,mu,c,ln);assert fast(v,lin(v,ap),ap)==independent_clauses(v,am,mu,c,ln);checks['aliased_values']+=1
          wrong=pp[0].copy();wrong[mm['A_X']]=Z
          controls['alias_overwrite']|=lin(v,ap)!=lin(v,(dict(ap[0],**{} )|{am['A_X']:Z},ap[1],ap[2]))
          controls['toy_index_fails']|=v[m['A_X']]!=v[8]
          controls['changed_helper_order']|=full(v,fast(v,ls[0],p),m,list(reversed(lk)),h0,mu,nu,c,supp,zeta)!=native(v,m,lk,idx,h0,ln,mu,nu,c,supp,zeta)
          bad=v[:];bad[lk[0][0]]=Z;controls['drop_helper_column']|=full(bad,fast(v,ls[0],p),m,lk,h0,mu,nu,c,supp,zeta)!=full(v,fast(v,ls[0],p),m,lk,h0,mu,nu,c,supp,zeta)
          stale=mu[:];stale[0]=add(stale[0],O);controls['stale_mu']|=fast(v,ls[0],prep(m,stale,c,ln))!=independent_clauses(v,m,stale,c,ln)
          controls['wrong_msb']|=logn>1 and cube(original[5],rs)!=cube(original[5],list(reversed(rs)))
          controls['missing_original_final']|=len(v[:-1])!=nt
          if padded:controls['support_omission']|=full(v,fast(v,ls[0],p),m,lk,h0,mu,nu,c,None,zeta)!=full(v,fast(v,ls[0],p),m,lk,h0,mu,nu,c,supp,zeta)
          try:
            bm=m.copy();bm['A_X']=nt
            if any(j>=nt for j in bm.values()):raise ValueError('public binding outside table list')
          except ValueError:checks['refusals']+=1;controls['bad_binding_refused']=True
          checks['fixtures']+=1
    assert all(controls.values()),controls
    result={'status':'PASS','seed':SEED,'run_id':'20261018T042105Z-c9fe8fca','checks':checks,'controls':controls,'catalogs':census,'synthetic_digest':digest.hexdigest(),'wall_seconds':time.perf_counter()-start,'rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'compiler_rss_kib':resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,'cpu_affinity':[cpu],'threads':1,'platform':platform.platform(),'compiler_argv':argv,'scope':'Captured native Ids/a_range/lookups_at/full D expression with shape and u128 field substitutes; synthetic values only, public trained profile scalars. No native proof/PTX/CUDA/RNG/privacy or runtime speed result.'}
    (H/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='catalogs'},indent=2))
if __name__=='__main__':main()
