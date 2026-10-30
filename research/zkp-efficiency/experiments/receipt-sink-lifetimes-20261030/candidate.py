"""Locally authored wire-shape projection, not a native prover or verifier.

Bounded emission preserves raw u64 representations. Typed-field canonicality
is an independent decoder obligation, as in the source run encoder.
"""
import hashlib

def dimensions(g, incoming=False):
    n = g['en'] if incoming else g['n']
    return (n + g['q'], n * g['rate'], (n * g['rate']).bit_length()-1)

def expected_len(g):
    def op(groups, rows, endpoint=False):
        v, _, p = dimensions(g, endpoint)
        return 16*(groups+1)*v + g['q']*(8+8*rows+32+32*p)
    slots = sum(16*(1+r*(d+1)+t) for r,d,t in g['slots'])
    mask = 32768+g['q']*(8+8*g['mr']+32+384)
    gi,ri = (1,g['er']) if g['k']==0 else (g['sites'],g['br'])
    return 88+32*(g['k']+1<g['l'])+96+slots+mask+op(g['ag'],g['ar'])+op(g['hg'],g['hr'])+op(gi,ri,True)+op(1,g['er'],True)*(g['k']+1==g['l'])+32

def validate(s, g):
    if len(s['slots']) != len(g['slots']): raise ValueError('slot count')
    for sp,(r,d,t) in zip(s['slots'],g['slots']):
        if len(sp['rounds'])!=r or any(len(x)!=d+1 for x in sp['rounds']) or len(sp['terms'])!=t: raise ValueError('argument shape')
    if (s['b'] is not None)!=(g['k']+1<g['l']) or (s['out'] is not None)!=(g['k']+1==g['l']): raise ValueError('schedule')
    def cols(cs, rows, width, path):
        return len(cs)==g['q'] and all(0<=j<width and len(c)==rows and len(p)==path for j,c,salt,p in cs)
    m=s['mask']
    if len(m['q'])!=1024 or len(m['prox'])!=1024 or not cols(m['cols'],g['mr'],4096,12): raise ValueError('opening shape')
    gi,ri = (1,g['er']) if g['k']==0 else (g['sites'],g['br'])
    for o,groups,rows,endpoint in [(s['a'],g['ag'],g['ar'],False),(s['h'],g['hg'],g['hr'],False),(s['in'],gi,ri,True)]+([(s['out'],1,g['er'],True)] if s['out'] else []):
        v,w,p=dimensions(g,endpoint)
        if len(o['groups'])!=groups or any(len(x)!=v for x in o['groups']) or len(o['prox'])!=v or not cols(o['cols'],rows,w,p): raise ValueError('opening shape')
    if expected_len(g)>g['ceiling']: raise ValueError('segment exceeds bound')

class ChunkWriter:
    def __init__(self, sink, limit):
        if limit<=0: raise ValueError('chunk budget')
        self.sink=sink; self.limit=limit; self.buf=bytearray(); self.high=0; self.count=0; self.hash=hashlib.sha256(); self.calls=0
    def emit(self, data):
        view=memoryview(data)
        while view:
            take=min(self.limit-len(self.buf),len(view))
            self.buf.extend(view[:take]);view=view[take:]
            self.high=max(self.high,len(self.buf))
            if len(self.buf)==self.limit:self.flush()
    def flush(self):
        view=memoryview(self.buf)
        while view:
            try:n=self.sink.write(view)
            except InterruptedError:continue
            self.calls+=1
            if n<=0 or n>len(view):raise OSError('write made no progress')
            self.hash.update(view[:n]);self.count+=n;view=view[n:]
        del view
        self.buf.clear()
    def finish(self):self.flush();return self.count,self.hash.hexdigest()

def emit_segment(s,g,binding,start,end,writer):
    validate(s,g) # all shape checks before the first write
    def u(x):writer.emit(x.to_bytes(8,'little'))
    def f(x):u(x[0]);u(x[1])
    def col(columns):
        for j,c,salt,path in columns:
            u(j)
            for x in c:u(x)
            writer.emit(salt)
            for x in path:writer.emit(x)
    def opening(o):
        for group in o['groups']:
            for x in group:f(x)
        for x in o['prox']:f(x)
        col(o['cols'])
    writer.emit(b'HLPRUNS1');writer.emit(binding);u(g['l']);u(g['k']);writer.emit(start)
    if s['b'] is not None:writer.emit(s['b'])
    for name in ['aroot','hroot','mroot']:writer.emit(s[name])
    for sp in s['slots']:
        f(sp['scalar'])
        for row in sp['rounds']:
            for x in row:f(x)
        for x in sp['terms']:f(x)
    for name in ['q','prox']:
        for x in s['mask'][name]:f(x)
    col(s['mask']['cols'])
    for name in ['a','h','in']:opening(s[name])
    if s['out'] is not None:opening(s['out'])
    writer.emit(end)
    result=writer.finish()
    if result[0]!=expected_len(g):raise ValueError('counted length')
    return result
