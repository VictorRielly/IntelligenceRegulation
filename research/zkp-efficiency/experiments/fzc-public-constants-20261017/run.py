#!/usr/bin/env python3
"""Source-captured F zero-check; independent integer-pair reference.

Only synthetic values. No Cargo build, production execution, GPU, or dependencies.
"""
import ctypes
import difflib
import hashlib
import json
import os
from pathlib import Path
import random
import resource
import signal
import subprocess
import time

HERE = Path(__file__).resolve().parent
P = 2**64 - 2**32 + 1
ZERO, ONE = (0, 0), (1, 0)


def add(a, b): return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)
def sub(a, b): return ((a[0] - b[0]) % P, (a[1] - b[1]) % P)
def mul(a, b): return ((a[0]*b[0] + 7*a[1]*b[1]) % P, (a[0]*b[1] + a[1]*b[0]) % P)
def scale(a, b): return (a[0]*b % P, a[1]*b % P)
def summ(xs):
    a = ZERO
    for x in xs: a = add(a, x)
    return a


def reference(v, hh, gg, pad, nlk, mutant=None):
    """Semantic equation, without calling or translating the Rust closure."""
    eq, eg, eu = v[:3]
    gate, rg, act, up, ul, uh, prod, hl, hi, rl, rh = v[3:14]
    alpha, beta, tag_act, tag_u8 = v[21:25]
    mu, nu = v[25:35], v[35:37]
    supp = v[20] if pad else ONE
    kh, kg = 2**hh, 2**gg
    half_h, half_g = (2**(hh-1) if hh else 0), (2**(gg-1) if gg else 0)
    clauses = [sub(add(sub(mul(act, up), scale(prod, kh)), (half_h, 0)), add(rl, scale(rh, 256))),
               sub(add(up, (32768, 0)), add(ul, scale(uh, 256))),
               sub(add(prod, (32768, 0)), add(hl, scale(hi, 256)))]
    fact = v[14] if mutant == 'wrong helper index' else v[19]
    activation = sub(mul(fact, sub(alpha, summ([gate, (128, 0), mul(beta, act), tag_act]))), ONE)
    if mutant == 'activation incorrectly gated': activation = mul(activation, supp)
    columns = [rg, scale(rg, 2**(8-gg)), ul, uh, hl, hi, rl, rh, scale(rh, 2**(16-hh))][:nlk]
    ds = [sub(alpha, add(tag_u8, z)) for z in columns]
    helpers = []
    for i in range(0, nlk, 2):
        if i+1 < nlk:
            rel = sub(mul(v[14+i//2], mul(ds[i], ds[i+1])), add(ds[i], ds[i+1]))
        else: rel = sub(mul(v[14+i//2], ds[i]), ONE)
        helpers.append(mul(mu[4+i//2], rel))
    hs = summ(helpers)
    if mutant == 'helpers incorrectly gated': hs = mul(supp, hs)
    ps = ZERO
    if pad:
        zeta, power = v[37], ONE
        terms = []
        for z in v[3:14]:
            terms.append(mul(power, z)); power = mul(power, zeta)
        ps = mul(mu[4+(nlk+1)//2], mul(sub(ONE, supp), summ(terms)))
    if mutant == 'pad term dropped': ps = ZERO
    zc = summ([hs, mul(mu[3], activation), ps, mul(supp, summ(mul(mu[i], clauses[i]) for i in range(3)))])
    if mutant == 'whole bracket gated': zc = mul(supp, zc)
    hg = sub(add(scale(gate, kg), rg), (half_g, 0))
    if mutant == 'host half omitted': hg = add(scale(gate, kg), rg)
    host_supp = ONE if mutant == 'host gate omitted' else supp
    out = summ([mul(eq, zc), mul(mul(nu[0], eg), mul(host_supp, hg)), mul(mul(nu[1], eu), mul(host_supp, up))])
    return out


def balanced(src, start):
    b = src.index('{', start); depth, end = 1, b+1
    while depth:
        depth += (src[end] == '{') - (src[end] == '}'); end += 1
    return src[start:end]


def prepare():
    src = (HERE/'native/argument.rs').read_text()
    arm_start = src.index('        SC_FZC => {')
    arm = balanced(src, arm_start)
    baseline = balanced(arm, arm.index('let poly = move'))
    assert baseline.count('at(o + 1).mul(p1)') == 1
    assert baseline.count('k_h.mul(h16)') == baseline.count('k_g.mul(g8)') == 1
    old_loop = '''for (m, c) in mu.iter().zip([f0, f1, f2]) {
                    zc = zc.add(m.mul(g).mul(c));
                }'''
    assert old_loop in baseline
    new_loop = '''let mut clauses = Fp2::ZERO;
                for (m, c) in mu.iter().zip([f0, f1, f2]) {
                    clauses = clauses.add(m.mul(c));
                }
                zc = zc.add(g.mul(clauses));'''
    bodies = []
    for mode in range(4):
        body = baseline
        if mode & 1:
            body = body.replace('at(o + 1).mul(p1)', 'at(o + 1).mul_base(b1)')
            body = body.replace('k_h.mul(h16)', 'h16.mul_base(b_h)').replace('k_g.mul(g8)', 'g8.mul_base(b_g)')
        if mode & 2: body = body.replace(old_loop, new_loop)
        bodies.append(body)
    # Review patch: only the actual F arm changes; no transcript/definition edits.
    candidate_arm = arm.replace(baseline, bodies[3])
    candidate_arm = candidate_arm.replace('let (k_h, k_h_half, k_g, k_g_half) = (k(1i64 << sh.sh_h), k(super::witness::half(sh.sh_h)), k(1i64 << sh.sh_g), k(super::witness::half(sh.sh_g)));',
        'let (b_h, k_h_half, b_g, k_g_half) = (Fp::from_i64(1i64 << sh.sh_h), k(super::witness::half(sh.sh_h)), Fp::from_i64(1i64 << sh.sh_g), k(super::witness::half(sh.sh_g)));\n            let b1 = Fp::from_i64(256);')
    assert candidate_arm != arm and 'let b1' in candidate_arm
    candidate = src.replace(arm, candidate_arm)
    (HERE/'argument-candidate.rs').write_text(candidate)
    (HERE/'argument-candidate.patch').write_text(''.join(difflib.unified_diff(src.splitlines(True), candidate.splitlines(True), fromfile='a/hashline/src/private_block/argument.rs', tofile='b/hashline/src/private_block/argument.rs')))
    (HERE/'captured-closure.rs.txt').write_text(baseline+';\n')
    helper = balanced(src, src.index('fn helper_sum('))
    padterm = balanced(src, src.index('struct PadTerm {')) + '\n' + balanced(src, src.index('impl PadTerm {'))
    gate = '#[derive(Clone, Copy)]\nstruct Gate(Option<usize>);\n' + balanced(src, src.index('impl Gate {'))
    constants = '\n'.join(l.replace('pub(crate) ', '') for l in (HERE/'native/layout.rs').read_text().splitlines() if l.startswith('pub(crate) const A_') and any((' '+z+':') in l for z in ['A_G8','A_RGL','A_A16','A_U16','A_UL0','A_UL1','A_H16','A_HL0','A_HL1','A_RH0','A_RH1']))
    code = '#![allow(dead_code,unused_variables)]\nmod field {\n' + (HERE/'native/field.rs').read_text().replace('//!','//') + '\n}\nuse field::{Fp,Fp2};\n'
    code += constants + '\nstruct LkT { terms: Vec<(usize,Fp)>, cst: Fp2 }\n' + helper + '\n' + padterm + '\n' + gate + '\nfn k(x:i64)->Fp2 { Fp2::from_i64(x) }\n'
    for mode, body in enumerate(bodies):
        code += f'''#[inline(never)]
fn factory_{mode}(v: &[Fp2], hh:u32, gg:u32, pad:bool, nlk:usize) -> Box<dyn Fn(&[Fp2])->Fp2> {{
 let mut idx=vec![usize::MAX;78]; for i in 67..=77 {{ idx[i]=i-64; }}
 let (h0,i_fact)=(14,19); let mu=v[25..35].to_vec(); let nu=v[35..37].to_vec();
 let (alpha,beta,g_act,g_u8)=(v[21],v[22],v[23],v[24]);
 let p1=k(256); let b1=Fp::from_i64(256);
 let (k_h,k_g,b_h,b_g)=(k(1i64<<hh),k(1i64<<gg),Fp::from_i64(1i64<<hh),Fp::from_i64(1i64<<gg));
 let (k_h_half,k_g_half)=(k(if hh==0 {{0}} else {{1i64<<(hh-1)}}),k(if gg==0 {{0}} else {{1i64<<(gg-1)}}));
 let cols=[(A_RGL,1),(A_RGL,1i64<<(8-gg)),(A_UL0,1),(A_UL1,1),(A_HL0,1),(A_HL1,1),(A_RH0,1),(A_RH1,1),(A_RH1,1i64<<(16-hh))];
 let lks:Vec<LkT>=cols[..nlk].iter().map(|(p,c)| LkT{{terms:vec![(idx[*p],Fp::from_i64(*c))],cst:g_u8}}).collect();
 let gf=Gate(if pad {{Some(20)}} else {{None}}); let mut pz=PadTerm::none();
 if pad {{ pz.mu=mu[4+nlk.div_ceil(2)]; pz.add(Some(20),&(3..14).collect::<Vec<_>>(),v[37]); }}
 {body}; Box::new(poly)
}}
'''
    code += '''#[no_mangle]
pub unsafe extern "C" fn fzc(out:*mut u64, words:*const u64, hh:u32,gg:u32,pad:u32,nlk:usize,mode:u32) {
 let w=std::slice::from_raw_parts(words,76); let v:Vec<Fp2>=w.chunks_exact(2).map(|x|Fp2::new(Fp(x[0]),Fp(x[1]))).collect();
 let f=match mode {0=>factory_0(&v,hh,gg,pad!=0,nlk),1=>factory_1(&v,hh,gg,pad!=0,nlk),2=>factory_2(&v,hh,gg,pad!=0,nlk),_=>factory_3(&v,hh,gg,pad!=0,nlk)};
 let z=f(&v[..21]); *out=z.c0.0; *out.add(1)=z.c1.0;
}
'''
    (HERE/'isolated.rs').write_text(code)
    return bodies


def main():
    t0 = time.perf_counter(); os.nice(19); os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2)); resource.setrlimit(resource.RLIMIT_CPU,(59,59)); signal.alarm(59)
    bodies = prepare()
    rustc='/home/victor/.rustup/toolchains/1.97.0-x86_64-unknown-linux-gnu/bin/rustc'
    argv=[rustc,'--edition=2021','--crate-type=cdylib','-C','opt-level=3','-C','codegen-units=1','--emit=link,asm,llvm-ir','isolated.rs','-o','isolated.so']
    cp=subprocess.run(argv,cwd=HERE,capture_output=True,text=True,timeout=30)
    (HERE/'compile.log').write_text(cp.stdout+cp.stderr); assert cp.returncode==0,cp.stderr
    lib=ctypes.CDLL(str(HERE/'libisolated.so')); fn=lib.fzc
    fn.argtypes=[ctypes.POINTER(ctypes.c_uint64),ctypes.POINTER(ctypes.c_uint64),ctypes.c_uint32,ctypes.c_uint32,ctypes.c_uint32,ctypes.c_size_t,ctypes.c_uint32]
    def native(v,hh,gg,pad,nlk,mode):
        words=(ctypes.c_uint64*76)(*(w for a in v for w in a)); out=(ctypes.c_uint64*2)()
        fn(out,words,hh,gg,pad,nlk,mode); return tuple(out)
    rng=random.Random(2026101763); digest=hashlib.sha256(); counts=dict(fixtures=0,comparisons=0,round_samples=0,folded_terminals=0)
    modes=['baseline','base constants','support hoist','combined']
    mutations=['activation incorrectly gated','helpers incorrectly gated','pad term dropped','whole bracket gated','wrong helper index','host gate omitted','host half omitted']
    caught={m:False for m in mutations}
    seeds=[0,1,255,256,32768,P-1,P-2,2**32-1,2**32,2**63]
    costs={}
    for i in range(480):
        hh,gg,pad,nlk=[0,1,7,8,9,14,16][i%7], [0,1,7,8][(i//7)%4], bool((i//28)%2), [0,1,2,3,8,9][(i//56)%6]
        v=[(rng.randrange(P),rng.randrange(P)) for _ in range(38)]
        if i%5==0: v=[(seeds[(i+j)%len(seeds)], seeds[(i+2*j)%len(seeds)]) for j in range(38)]
        if i%5==1: v=[(a,0) for a,b in v]
        if pad: v[20]=[ZERO,ONE,(3,7),(P-1,P-2)][(i//2)%4]
        ref=reference(v,hh,gg,pad,nlk)
        for mode in range(4):
            got=native(v,hh,gg,pad,nlk,mode); assert got==ref,(i,mode,got,ref)
            digest.update(bytes(str(got),'ascii')); counts['comparisons']+=1
        for m in mutations:
            caught[m] |= reference(v,hh,gg,pad,nlk,m)!=ref
        counts['fixtures']+=1
    # Toy ordinary sumcheck sampling: real MLE interpolation at full extension
    # challenges, all row samples and final terminals. This is not masked proving.
    for pad in [False,True]:
      for n in [1,2,3,5]:
        v=[(rng.randrange(P),rng.randrange(P)) for _ in range(38)]
        tabs=[[(rng.randrange(P),rng.randrange(P)) for _ in range(2**n)] for _ in range(21)]
        for rd in range(n):
          half=len(tabs[0])//2
          for t in [(0,0),(1,0),(2,0),(3,0),(4,0),(13,19)]:
            sums=[ZERO]*4; refsum=ZERO
            for j in range(half):
              row=[add(a[j],mul(t,sub(a[j+half],a[j]))) for a in tabs]
              vv=row+v[21:]
              refsum=add(refsum,reference(vv,14,8,pad,9))
              for mode in range(4): sums[mode]=add(sums[mode],native(vv,14,8,pad,9,mode))
            assert all(s==refsum for s in sums); counts['round_samples']+=4;counts['comparisons']+=4
          rho=(rng.randrange(P),rng.randrange(P))
          tabs=[[add(a[j],mul(rho,sub(a[j+half],a[j]))) for j in range(half)] for a in tabs]
        vv=[a[0] for a in tabs]+v[21:]; ref=reference(vv,14,8,pad,9)
        assert all(native(vv,14,8,pad,9,m)==ref for m in range(4));counts['folded_terminals']+=4; counts['comparisons']+=4
    assert all(caught.values()),caught
    # Extension coefficients can never be truncated merely because the original
    # witness was base-valued. Deliberately wrong general mul_base substitutions.
    a,b=(2,3),(5,7)
    assert mul(a,b)!=scale(a,b[0]); caught['challenge coefficient truncated']=True
    assert reference(vv,14,8,True,9)!=reference([*vv[:19],ZERO,*vv[20:]],14,8,True,9); caught['activation helper dropped']=True
    # Source/API count before LLVM: 5 full extension calls -> 5 base calls;
    # hoisting saves 2 general calls. F has 9 affine lookup columns / 5 helpers.
    # Native Fp2::mul invokes 5 Fp::mul; mul_base invokes 2. Compiler can remove
    # zero/one/constant operations; this count is NOT an instruction/time model.
    for mode in range(4):
        fixed_full=22-(5 if mode&1 else 0)-(2 if mode&2 else 0)
        helper_full=14 # four paired helpers (3 each) and one singleton (2)
        # PadTerm::eval always executes mu*acc even with no groups.
        costs[modes[mode]]=dict(nonhelper_full_extension_calls=fixed_full,
            constant_base_calls=5 if mode&1 else 0,helper_full_extension_calls=helper_full,
            helper_base_calls=9,pad_full_extension_calls_unpadded=1,pad_full_extension_calls_padded=13,
            full_extension_calls_unpadded=fixed_full+helper_full+1,full_extension_calls_padded=fixed_full+helper_full+13)
    out=dict(status='pass',run_id='20261017T132624Z-393ef603',cycle='0063',seed=2026101763,counts=counts,controls=caught,costs=costs,
             output_sha256=digest.hexdigest(),wall_seconds=time.perf_counter()-t0,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
             child_peak_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,cpu_affinity=sorted(os.sched_getaffinity(0)),threads=1,nice=os.getpriority(os.PRIO_PROCESS,0),
             compile_argv=argv,source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),limits='59s CPU/wall,512MiB AS, one thread; standalone std-only harness; no Cargo/native proof/GPU',
             scope='source-captured Rust arithmetic vs independent Python arbitrary-integer Fp2 reference; synthetic ordinary round samples; no masked proof, transcript, PCS, RNG, privacy or native runtime acceptance')
    (HERE/'result.json').write_text(json.dumps(out,indent=2)+'\n'); print(json.dumps(out))


if __name__=='__main__': main()
