"""Static x86 assembly/call-chain utility; audit_shared.py is the entry point."""
import re,subprocess
from pathlib import Path
H=Path(__file__).resolve().parent

def assembly():
    text=(H/'kernels.s').read_text();ans={}
    for m in re.finditer(r'^([A-Za-z_][A-Za-z_0-9.$]*):\n(.*?)(?=^\.Lfunc_end)',text,re.M|re.S):
        name,f=m.groups()
        subs=[int(x) for x in re.findall(r'^\s*subq\s+\$(\d+), %rsp',f,re.M)]
        adds=[int(x) for x in re.findall(r'^\s*addq\s+\$(\d+), %rsp',f,re.M)]
        assert subs==adds and len(subs)<=1
        pushes=len(re.findall(r'^\s*pushq\s',f,re.M));pops=len(re.findall(r'^\s*popq\s',f,re.M));assert pushes==pops
        redzone=max([0]+[-int(x) for x in re.findall(r'(-\d+)\(%rsp\)',f)])
        calls=re.findall(r'^\s*callq\s+([^\s#]+)',f,re.M)
        assert not re.search(r'^\s*j(?!mp)[a-z]+\s',f,re.M)
        ans[name]=dict(local_sub_bytes=sum(subs),push_bytes=8*pushes,red_zone_bytes=redzone,
             own_span_below_entry_rsp_bytes=sum(subs)+8*pushes+redzone,
             calls=calls,call_count=len(calls),instruction_lines=len(re.findall(r'^\s+[a-z][a-z0-9]*\s',f,re.M)),
             rsp_references=len(re.findall(r'\(%rsp\)',f)))
    for n in ans:
        assert all(c in ans for c in ans[n]['calls']),ans[n]
    def span(n,seen=()):
        assert n not in seen
        a=ans[n];callee=max([0]+[8+span(c,seen+(n,)) for c in a['calls']])
        # Caller has no red-zone allocation when making calls in this build.
        assert not a['calls'] or a['red_zone_bytes']==0
        return a['own_span_below_entry_rsp_bytes']+callee
    for n in ans:ans[n]['call_chain_span_below_entry_rsp_bytes']=span(n)
    cp=subprocess.run(['nm','-S','--defined-only',str(H/'libkernels.so')],capture_output=True,text=True,timeout=5)
    assert cp.returncode==0;(H/'symbols.log').write_text(cp.stdout)
    for line in cp.stdout.splitlines():
        a=line.split()
        if len(a)==4 and a[3] in ans:ans[a[3]]['symbol_bytes']=int(a[1],16)
    return ans


