import re, difflib, importlib.util, sys, io, contextlib
spec = importlib.util.spec_from_file_location('sd', 'sigdiff.py')
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    sd = importlib.util.module_from_spec(spec); spec.loader.exec_module(sd)
def toks(s):
    s = s.replace('ZK60.ProtocolClassify.', '')
    return re.findall(r"[^\s()]+|[()]", s)
for k in ['hTrIIO','hTrOIO','hLI_stg','hLO_stg','hdinS','hdoutS','hdzW','hNin','hPin']:
    a = toks(sd.od[k][1]); b = toks(sd.nd[k][1])
    print('=====', k)
    sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
    for op, i1, i2, j1, j2 in sm.get_opcodes():
        if op != 'equal':
            print(' ', op, 'OLD:', ' '.join(a[i1:i2])[:300], '|| NEW:', ' '.join(b[j1:j2])[:500])
