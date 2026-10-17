#!/usr/bin/env python3
"""Own synthetic plane-assembly oracle and allocation-free source census."""
import collections, difflib, hashlib, json, os, random, re, resource, signal, time
from pathlib import Path

HERE = Path(__file__).resolve().parent
SEED = 2026101761
RUN = '20261017T112624Z-88d6b64e'

def pow2(n): return 1 << (n-1).bit_length()

def catalog(text, ln=4, ls=2, lp=2):
    constants = {k:int(v) for k,v in re.findall(r'const (A_\w+): usize = (\d+);',text)}
    segtext = text.split('let segs:')[1].split('let mut map')[0]
    segs = re.findall(r'\((A_\w+), (\d+|LN_TOY|LS_TOY|LP_TOY), (\d+|ln|ls|lp), Dom::(\w+)\)',segtext)
    assert len(segs)==18
    env={'LN_TOY':4,'LS_TOY':2,'LP_TOY':2,'ln':ln,'ls':ls,'lp':lp}
    ids={}; doms=[]; groups={}
    for first,old,new,dom in segs:
        old=int(old) if old.isdigit() else env[old]
        new=int(new) if new.isdigit() else env[new]
        start=constants[first]; base=len(doms)
        for name,val in constants.items():
            if start<=val<start+old: ids[name]=base+val-start
        groups[first]=list(range(base,base+new))
        doms += [dom]*new
    # Independently expressed named domain families from the memo.
    reference=['T']*4+['Ht']*2+['L']*2+['D']*(19+4*ln)+['Q']*7+['Kv']*6+['S']*(5+lp+2*ls)+['F']*11+['Tab']*3
    assert doms==reference and len(ids)==81
    return ids,doms,groups

def replacements(wtext,ids,groups):
    build=wtext.split('pub(crate) fn build_shaped(')[1]
    direct=re.findall(r'^    pl\[ap\((A_\w+)\)\] = (\w+(?:\.\w+)?);',build,re.M)
    assert len(direct)==27, len(direct)
    moved={ids[n] for n,v in direct}
    for name in ['A_NR0','A_NS0','A_MR0','A_MS0']: moved.update(groups[name])
    # Independent classification by semantic output families.
    names={'A_D','A_DSQ','A_LIMB','A_Y','A_DM','A_DSQM','A_LIMBM','A_YM',
           'A_AO','A_RAL','A_Q8','A_RQL','A_QR8','A_RQRL','A_O8',
           'A_K8','A_RKL','A_V8','A_RVL','A_KR8','A_RKRL','A_S8','A_RSL',
           'A_G8','A_RGL','A_A16','A_U16','A_H16','A_Z16','A_RDL'}
    assert {n for n,v in direct}==names
    return moved,direct

def lengths(t,d,f,h,kv,dh,n):
    tp,dp,fp,hp=map(pow2,(t,d,f,h))
    x={'T':tp,'Ht':hp*tp,'L':16*tp,'D':tp*dp,'Q':tp*hp*dh,'Kv':tp*kv*dh,'S':hp*tp*tp,'F':tp*fp,'Tab':256}
    return {k:(v if k in ('T','Ht') else max(n,v)) for k,v in x.items()}

def assemble(doms,lens,moved,events,lazy):
    planes=[[] if dom=='Tab' or (lazy and p in moved) else [0]*lens[dom] for p,dom in enumerate(doms)]
    for kind,p,data in events:
        if kind=='move': planes[p]=list(data)
        elif kind=='write':
            for i,v in data: planes[p][i]=v
        elif kind=='read':
            if len(planes[p])!=lens[doms[p]]: raise ValueError('premature read')
    if any(len(v)!=(0 if doms[p]=='Tab' else lens[doms[p]]) for p,v in enumerate(planes)):
        raise ValueError('incomplete plane')
    return planes

def reference(doms,lens,events):
    # Sparse last-write map, independent of eager/lazy Vec replacement strategy.
    cells={}; moves={}
    for kind,p,data in events:
        if kind=='move':
            moves[p]=tuple(data)
            cells={key:v for key,v in cells.items() if key[0]!=p}
        elif kind=='write':
            for i,v in data: cells[p,i]=v
    return [[] if dom=='Tab' else [cells.get((p,i),moves[p][i] if p in moves else 0) for i in range(lens[dom])] for p,dom in enumerate(doms)]

def main():
    start=time.perf_counter(); os.nice(19); os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2)); resource.setrlimit(resource.RLIMIT_CPU,(59,59)); signal.alarm(59)
    rng=random.Random(SEED); lt=(HERE/'native/layout.rs').read_text(); wt=(HERE/'native/witness.rs').read_text()
    counts=collections.Counter(); digest=hashlib.sha256(); controls=[]
    for fixture in range(72):
        ls=2+fixture%2; lp=2+(fixture%3==0)
        ids,doms,groups=catalog(lt,4,ls,lp); moved,direct=replacements(wt,ids,groups)
        lens=lengths(1+fixture%7,8,12,2,1,4,32)
        events=[]
        for p,dom in enumerate(doms):
            if dom=='Tab': continue
            n=lens[dom]
            if p in moved:
                # Full vectors intentionally include arbitrary padded words;
                # the optimization must preserve the producer, never zero it.
                data=[rng.randrange(-32768,32768) for i in range(n)]
                events.append(('move',p,data))
            else:
                data=[(i,rng.randrange(-32768,32768)) for i in range(n) if i%3!=1]
                events.append(('write',p,data))
            events.append(('read',p,None))
        # Exp is NOT moved: include the second full padded pass in native order.
        ep=ids['A_E']; events.append(('write',ep,[(i,512+(i%11)) for i in range(lens['S'])]))
        base=assemble(doms,lens,moved,events,False); lazy=assemble(doms,lens,moved,events,True); ref=reference(doms,lens,events)
        assert base==lazy==ref
        counts['fixtures']+=1; counts['plane_checks']+=len(base); counts['word_checks']+=sum(map(len,base))
        digest.update(json.dumps(lazy,separators=(',',':')).encode())
        if fixture==0:
            def reject(name,fn):
                try: fn()
                except (ValueError,IndexError,AssertionError): controls.append(name); return
                raise AssertionError('control did not fail: '+name)
            p=next(iter(moved))
            reject('premature moved-plane read',lambda:assemble(doms,lens,moved,[('read',p,None)]+events,True))
            reject('scatter plane incorrectly deferred',lambda:assemble(doms,lens,moved|{ids['A_X']},events,True))
            reject('missing final move',lambda:assemble(doms,lens,moved,[e for e in events if not(e[0]=='move' and e[1]==p)],True))
            bad=[(k,p0,data[:-1] if k=='move' and p0==p else data) for k,p0,data in events]
            reject('short producer vector',lambda:assemble(doms,lens,moved,bad,True))
            wrong=assemble(doms,lens,moved,events,True); wrong[ids['A_X']][1]=1
            reject('required untouched padding changed',lambda: (_ for _ in ()).throw(AssertionError()) if wrong!=ref else None)
            wrong=assemble(doms,lens,moved,events[:-1],True)
            reject('exp padded completion omitted',lambda: (_ for _ in ()).throw(AssertionError()) if wrong!=ref else None)
    ids,doms,groups=catalog(lt,4,2,2); moved,direct=replacements(wt,ids,groups)
    census=[]
    for model,d,f,h,kv,dh in [('TinyLlama1.1B',2048,5632,32,4,64),('Llama3-8B',4096,14336,32,8,128)]:
        for t in [32,64,128,256,512,1024]:
            n=4096*(t//32); ls=2 if (t.bit_length()-1+10)<=16 else 3
            ids,doms,groups=catalog(lt,4,ls,2); moved,direct=replacements(wt,ids,groups); z=lengths(t,d,f,h,kv,dh,n)
            census.append(dict(model=model,context=t,log_cols=n.bit_length()-1,ls=ls,
              scope='source payload count; not native peak; larger layouts not admitted by this study',
              final_plane_bytes=sum(z[dom]*8 for dom in doms if dom!='Tab'),
              avoided_initial_zero_payload_bytes=sum(z[doms[p]]*8 for p in moved),
              three_clone_payload_bytes=3*z['D']*8,score_support_index_bytes=h*t*t*8,
              moved_plane_count=len(moved),initial_plane_count=len(doms)-3))
    # Generate a review-only patch from the exact snapshot. No source writes outside HERE.
    ids,doms,groups=catalog(lt,4,2,2); moved,direct=replacements(wt,ids,groups)
    names=[name for name,_ in direct]
    old='    let mut pl: Vec<Vec<i64>> = (0..ids.n_a()).map(|q| if ids.is_multiplicity(q) { Vec::new() } else { vec![0i64; g.len(ids.dom(q))] }).collect();'
    assert wt.count(old)==1
    new='''    // Owned producers below replace these entire vectors before any read.
    // Every scatter plane keeps its original zero-filled padded domain.
    let mut moved_in = vec![false; ids.n_a()];
    for toy_id in [NAMES] { moved_in[ap(toy_id)] = true; }
    for k in 0..g.ln {
        for q in [ids.nr(k), ids.ns(k), ids.mr(k), ids.ms(k)] { moved_in[q] = true; }
    }
    let mut pl: Vec<Vec<i64>> = (0..ids.n_a()).map(|q| if ids.is_multiplicity(q) || moved_in[q] { Vec::new() } else { vec![0i64; g.len(ids.dom(q))] }).collect();'''.replace('NAMES',', '.join(names))
    candidate=wt.replace(old,new)
    (HERE/'witness-candidate.rs').write_text(candidate)
    (HERE/'witness-candidate.patch').write_text(''.join(difflib.unified_diff(wt.splitlines(True),candidate.splitlines(True),fromfile='a/hashline/src/private_block/witness.rs',tofile='b/hashline/src/private_block/witness.rs')))
    # Audit retained six owner samples; copy only public logs and metadata.
    root=Path('/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r3'); retained=[]; (HERE/'retained').mkdir(exist_ok=True)
    for p in sorted(root.glob('stack-*-ho00-*/prove.log')):
        if p.parent.name.endswith('-lie'): continue
        def ev(path,event):
            return [json.loads(l) for l in path.read_text().splitlines() if l.startswith('{') and json.loads(l).get('event')==event][0]
        pr=ev(p,'proved'); vr=ev(p.parent/'verify.log','verified')
        gp=json.loads((p.parent/'prove.guard.json').read_text()); gv=json.loads((p.parent/'verify.guard.json').read_text())
        assert pr['statement_identity']==vr['statement_identity'] and pr['receipt_bytes']==vr['receipt_bytes'] and pr['blocks']==vr['blocks']==22
        assert gp['exit']==gp['child_rc']==gv['exit']==gv['child_rc']==0 and not gp['guard_killed'] and not gv['guard_killed']
        assert (p.parent/'prove.done').read_text().strip()==(p.parent/'verify.done').read_text().strip()=='0'
        t=int(re.search(r'_T(\d+)',p.parent.name).group(1)); wall=gp['child_wall_seconds']; proof=pr['prove_run_seconds']-pr['of_which_witness_seconds']
        pins={}
        for name in ['prove.log','verify.log','prove.guard.json','verify.guard.json','prove.done','verify.done']:
            b=(p.parent/name).read_bytes(); pins[name]=hashlib.sha256(b).hexdigest(); (HERE/'retained'/(p.parent.name+'__'+name)).write_bytes(b)
        retained.append(dict(name=p.parent.name,context=t,passes=1,blocks=22,device=pr['gpu'],total_wall_s=wall,total_in_process_s=pr['total_seconds'],
          diagnostic_positions_per_second=t/wall,witness_and_extraction_s=pr['of_which_witness_seconds'],proof_including_sink_excluding_witness_s=proof,
          serialization_s=None,fresh_verification_s=vr['verify_seconds'],fresh_verifier_load_s=vr['load_seconds'],load_s=pr['load_seconds'],load_fraction_of_wall=pr['load_seconds']/wall,
          startup_s=None,startup_fraction=None,steady_rate=None,peak_rss_gib=gp['peak_rss_gib'],peak_vram_mib=gp['peak_vram_mib'],receipt_bytes=pr['receipt_bytes'],
          ideal_delete_all_witness_factor=wall/(wall-pr['of_which_witness_seconds']),source_pins=pins,
          scope='owner-retained diagnostic, fresh verifier log inspected not rerun; no privacy acceptance at trained shape; no8B credit'))
    assert len(retained)==6
    out=dict(status='pass',run_id=RUN,cycle='0061',seed=SEED,counts=dict(counts),controls=controls,output_sha256=digest.hexdigest(),allocation_free_census=census,
      retained_owner_samples=retained,patch_scope='uncompiled unapplied selective initial plane allocation only; clone removal not in patch',
      experiment_wall_seconds=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
      cpu_affinity=sorted(os.sched_getaffinity(0)),threads=1,nice=os.nice(0),limits='59s wall/CPU;512MiB AS;96MiB estimate;no GPU',
      scope='Python synthetic assembly and independent sparse last-write oracle; source counts and retained owner log audit; no native compile/proof/fresh verification',
      executed_source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
      proof_accounting=dict(accepted_complete_private_8b_proofs=0,passes=0,positions=0,context=None,steady_rate=None,total_workload_rate=None,startup_s=None,startup_fraction=None,witness_s=None,proof_s=None,serialization_s=None,independent_verification_s=None,proof_lag_s=None,drain_s=None,prefill_ran=False,resident_passes_ran=False,decode_ran=False))
    (HERE/'result.json').write_text(json.dumps(out,indent=2)+'\n'); print(json.dumps({k:out[k] for k in ['status','counts','controls','experiment_wall_seconds','peak_rss_kib']}))

if __name__=='__main__': main()
