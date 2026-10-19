#!/usr/bin/env python3
"""Independent DAG lifetime/operand/source and host assembly audit.

No emitter arithmetic imported. Stack figures are static allocations, not
dynamic traffic, GPU registers, a full prover resource footprint, or timings.
"""
import collections
import hashlib
import json
import os
import re
import resource
import signal
import subprocess
import time
from pathlib import Path
H=Path(__file__).resolve().parent


def peak(q,retain=False):
    ns=q['ops'];last={n['id']:n['id'] for n in ns}
    for n in ns:
        assert all(0<=d<n['id'] for d in n['deps'])
        for d in n['deps']:last[d]=n['id']
    for d in q['output']:last[d]=len(ns)
    if retain:
        for n in ns:
            if n['kind']=='load_raw':last[n['id']]=len(ns)
    events=collections.Counter()
    for n in ns:
        events[n['id']]+=n['words'];events[last[n['id']]+1]-=n['words']
    live=0;mx=0
    for t in sorted(events):live+=events[t];mx=max(mx,live)
    assert live==0
    # Direct interval reconstruction is independent of event aggregation.
    direct=max(sum(n['words'] for n in ns if n['id']<=t<=last[n['id']])
               for t in range(len(ns)))
    assert mx==direct
    return mx+5


def assembly(path):
    s=path.read_text();ans={}
    for name in ['baseline','driven']:
        assert s.count('\n'+name+':\n')==1
        f=s.split('\n'+name+':\n',1)[1].split('.Lfunc_end',1)[0]
        ls=f.splitlines()
        subs=[int(x) for x in re.findall(r'^\s*subq\s+\$(\d+), %rsp',f,re.M)]
        adds=[int(x) for x in re.findall(r'^\s*addq\s+\$(\d+), %rsp',f,re.M)]
        assert len(subs)==len(adds)==1 and subs==adds
        push=sum(bool(re.search(r'^\s*pushq\b',x)) for x in ls)
        pop=sum(bool(re.search(r'^\s*popq\b',x)) for x in ls)
        assert push==pop
        conditional=[x.strip() for x in ls if re.match(r'^\s*j(?!mp)[a-z]+\s',x)]
        ans[name]=dict(local_stack_allocation_bytes=subs[0],callee_saved_push_bytes=8*push,
            stack_decrement_without_return_address_bytes=subs[0]+8*push,
            instruction_lines=sum(bool(re.search(r'^\s+[a-z][a-z0-9]*\s',x)) for x in ls),
            call_instructions=sum(bool(re.search(r'^\s*callq\b',x)) for x in ls),
            rsp_address_references=len(re.findall(r'\(%rsp\)',f)),
            conditional_jumps=len(conditional),
            limitations='Static emitted x86-64 code; stack allocation is not spill traffic. Dynamic branches may belong to unchanged field arithmetic. No GPU allocation or speed claim.')
    return ans


def main():
    start=time.perf_counter();os.nice(19);cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    checks=0;r=json.loads((H/'result.json').read_text());qs=json.loads((H/'scalar-dags.json').read_text())
    want={'load_param':129,'load_raw':118,'sub':209,'mul':331,'add':272,'load_base':36,'base':72}
    rows={}
    for name,q in qs.items():
        ns=q['ops'];assert [n['id'] for n in ns]==list(range(len(ns)));checks+=1
        assert dict(collections.Counter(n['kind'] for n in ns))==want;checks+=1
        assert len(q['output'])==5 and len(set(q['output']))==5;checks+=1
        for k,n in [('load_param',129),('load_raw',118),('load_base',36)]:
            assert sorted(x['slot'] for x in ns if x['kind']==k)==list(range(n));checks+=1
        for n in ns:
            assert n['words']==(0.5 if n['kind']=='load_base' else 1)
            if n['kind'].startswith('load_'):assert not n['deps']
            else:assert len(n['deps'])==2
            checks+=1
        p=peak(q);assert p==q['lifetime']['with_five_word_round_accumulator'];checks+=1
        rows[name]=dict(peak_fp2_equivalents_including_accumulator=p,
             retain_all_raw_inputs_words=peak(q,True),
             params_bytes=16*129+8*36,raw_input_bytes=16*118,output_bytes=16*5,
             logical_requested_bytes_per_row=16*(129+118+5)+8*36,
             physical_DRAM_bytes=None)
    assert rows['driven']['peak_fp2_equivalents_including_accumulator']==26
    assert rows['baseline']['peak_fp2_equivalents_including_accumulator']==76;checks+=2
    assert rows['driven']['retain_all_raw_inputs_words']>76;checks+=1
    for pin in json.loads((H/'source-pins.json').read_text()):
        assert hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'];checks+=1
    assert (H/'native-field.rs').read_bytes()==Path(json.loads((H/'source-pins.json').read_text())[5]['path']).read_bytes();checks+=1
    assert r['field_mode']=='native' and r['status']=='PASS' and r['checks']['fixtures']==6;checks+=1
    assert len(r['controls'])==7 and all(r['controls'].values());checks+=1
    assert r['checks']['compiled_coefficients']==780 and r['checks']['original_finals']==354;checks+=1
    asm={'u128':assembly(H/'u128-pass/kernels.s'),'native':assembly(H/'kernels.s')}
    helpers=[]
    for match in re.finditer(r'^([A-Za-z_][A-Za-z_0-9.$]*):\n(.*?)(?=^\.Lfunc_end)',
                             (H/'kernels.s').read_text(),re.M|re.S):
        name,f=match.groups()
        if name in ['baseline','driven']:continue
        helpers.append(dict(symbol=name,
            local_stack_subtractions_bytes=[int(x) for x in re.findall(r'^\s*subq\s+\$(\d+), %rsp',f,re.M)],
            callee_saved_push_bytes=8*len(re.findall(r'^\s*pushq\s',f,re.M)),
            call_instructions=len(re.findall(r'^\s*callq\s',f,re.M)),
            conditional_jumps=len(re.findall(r'^\s*j(?!mp)[a-z]+\s',f,re.M))))
    assert len(helpers)==4 and all(q['call_instructions']==0 for q in helpers);checks+=1
    # Use symbol sizes from ELF as a separate code-size observation.
    cp=subprocess.run(['nm','-S','--defined-only',str(H/'libkernels.so')],capture_output=True,text=True,timeout=5)
    assert cp.returncode==0;checks+=1
    (H/'symbols.log').write_text(cp.stdout)
    for l in cp.stdout.splitlines():
        a=l.split()
        if len(a)==4 and a[3] in ['baseline','driven']:asm['native'][a[3]]['ELF_symbol_bytes']=int(a[1],16)
    for mode in asm:
        asm[mode]['candidate_stack_allocation_decreases']=asm[mode]['driven']['local_stack_allocation_bytes']<asm[mode]['baseline']['local_stack_allocation_bytes'];checks+=1
        assert asm[mode]['baseline']['call_instructions']==asm[mode]['driven']['call_instructions'];checks+=1
    out=dict(status='PASS',checks=checks,scalar_accounting=rows,assembly=asm,native_shared_Fp2_helpers=helpers,
             negative_controls={'retaining_raw_inputs_loses_peak_gain':True},
             wall_seconds=time.perf_counter()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
             threads=1,cpu_affinity=[cpu],limits='59sCPU/wall,512MiBAS,one nice19 CPU')
    (H/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))


if __name__=='__main__':main()
