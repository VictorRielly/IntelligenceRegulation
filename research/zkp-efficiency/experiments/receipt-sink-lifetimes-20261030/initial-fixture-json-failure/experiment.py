import copy,hashlib,json,math,os,random,resource,time
from pathlib import Path
import candidate as c
import reference as ref
E=Path(__file__).resolve().parent
SEED=20261030166
R=random.Random(SEED)
checks=negative=0
def check(ok):
    global checks
    checks+=1
    assert ok,checks
def refuses(fn):
    try:fn()
    except (ValueError,OSError,IndexError,KeyError):return True
    return False
def raw():return R.randbytes(32)
def f2():return (R.randrange(ref.P),R.randrange(ref.P))
def vector(n):return [f2() for _ in range(n)]
def cols(q,rows,width,path):return [(R.randrange(width),[R.randrange(ref.P) for _ in range(rows)],raw(),[raw() for _ in range(path)]) for _ in range(q)]
def fixture(g):
    def opening(groups,rows,n):return dict(groups=[vector(n+g['q']) for _ in range(groups)],prox=vector(n+g['q']),cols=cols(g['q'],rows,n*g['rate'],(n*g['rate']).bit_length()-1))
    gi,ri=(1,g['er']) if g['k']==0 else (g['sites'],g['br'])
    return dict(b=raw() if g['k']+1<g['l'] else None,aroot=raw(),hroot=raw(),mroot=raw(),slots=[dict(scalar=f2(),rounds=[vector(d+1) for _ in range(r)],terms=vector(t)) for r,d,t in g['slots']],mask=dict(q=vector(1024),prox=vector(1024),cols=cols(g['q'],g['mr'],4096,12)),a=opening(g['ag'],g['ar'],g['n']),h=opening(g['hg'],g['hr'],g['n']),**{'in':opening(gi,ri,g['en']),'out':opening(1,g['er'],g['en']) if g['k']+1==g['l'] else None})

class ModelDisk:
    """Explicit source-sink state model; no filesystem durability claim."""
    def __init__(self,short=1000000,fail=None,after=None,existing=False):
        self.short=short;self.fail=fail;self.after=after;self.existing=existing
        self.partial=None;self.final=None;self.metadata=[];self.events=[]
    def begin(self,k=0,expected=0,total=1):
        if k!=expected:raise ValueError('sink order')
        if k>=total:raise ValueError('sink range')
        if self.existing:raise ValueError('exists')
        if self.fail=='create':raise OSError('create')
        self.partial=bytearray();self.events.append('create')
    def write(self,b):
        if self.after is not None and len(self.partial)>=self.after:raise OSError('write')
        n=min(len(b),self.short)
        if self.after is not None:n=min(n,self.after-len(self.partial))
        if self.fail=='zero':return 0
        self.partial.extend(b[:n]);return n
    def finish(self,digest):
        if self.fail=='sync':raise OSError('sync')
        self.events.append('sync')
        if self.fail=='rename':raise OSError('rename')
        self.final=bytes(self.partial);self.partial=None;self.events.append('rename')
        self.metadata.append((len(self.final),digest));self.events.append('metadata')
    def state(self):return (bytes(self.partial) if self.partial is not None else None,self.final,self.metadata,self.events)

def baseline(s,g,tags,disk,**kw):
    data=ref.encode(s,g,*tags)
    disk.begin(**kw)
    offset=0
    while offset<len(data):
        n=disk.write(memoryview(data)[offset:])
        if n<=0:raise OSError('write made no progress')
        offset+=n
    disk.finish(hashlib.sha256(data).hexdigest())
def stream(s,g,tags,disk,budget,**kw):
    c.validate(s,g)
    if budget<=0:raise ValueError('chunk budget')
    disk.begin(**kw)
    w=c.ChunkWriter(disk,budget)
    size,digest=c.emit_segment(s,g,*tags,w)
    disk.finish(digest)
    return w

def main():
    global negative
    started=time.monotonic();results=[];saved=[];faults=0;badshapes=0
    for z in range(3):
      for l in [1,2,4]:
       for k in range(l):
        g=dict(n=8<<z,en=8<<(2-z),q=2<<z,rate=4,ar=7+z,hr=9+z,mr=5+z,er=7,br=10,sites=2,ag=2+z,hg=3+z,l=l,k=k,slots=[(1+i%4,1+i%3,i%5) for i in range(23)],ceiling=256*1024*1024)
        s=fixture(g);tags=(raw(),raw(),raw());data=ref.encode(s,g,*tags)
        check(len(data)==c.expected_len(g));check(ref.decode_equal(data,s,g,*tags))
        for budget in [1,7,64,1024,4096,len(data)+1]:
            disk=ModelDisk(short=37);w=stream(s,g,tags,disk,budget)
            check(disk.final==data);check(w.high<=budget);check(w.count==len(data));check(w.hash.hexdigest()==hashlib.sha256(data).hexdigest());check(disk.events==['create','sync','rename','metadata'])
            results.append(dict(z=z,l=l,k=k,bytes=len(data),budget=budget,buffer_high=w.high,write_calls=w.calls))
        for opts in [dict(fail=x) for x in ['create','sync','rename','zero']]+[dict(after=n) for n in [0,1,87,len(data)//2,len(data)-1]]+[dict(existing=True)]:
            a=ModelDisk(short=31,**opts);b=ModelDisk(short=31,**opts)
            check(refuses(lambda:baseline(s,g,tags,a)));check(refuses(lambda:stream(s,g,tags,b,1024)));check(a.state()==b.state());check(not a.metadata and not b.metadata)
            faults+=1;negative+=1
        for kw in [dict(k=1,expected=0,total=l),dict(k=l,expected=l,total=l)]:
            a=ModelDisk();b=ModelDisk();check(refuses(lambda:baseline(s,g,tags,a,**kw)));check(refuses(lambda:stream(s,g,tags,b,64,**kw)));check(a.state()==b.state());negative+=1
        mutations=[]
        def add(fn):
            b=copy.deepcopy(s);fn(b);mutations.append(b)
        add(lambda b:b['slots'].pop());add(lambda b:b['slots'][0]['rounds'].pop());add(lambda b:b['slots'][0]['rounds'][0].pop());add(lambda b:b['slots'][0]['terms'].append(f2()));add(lambda b:b['mask']['q'].pop());add(lambda b:b['mask']['prox'].pop());add(lambda b:b['a']['groups'].pop());add(lambda b:b['h']['prox'].pop());add(lambda b:b['in']['cols'].pop());add(lambda b:b['mask']['cols'][0][3].pop());add(lambda b:b['a']['cols'][0][1].pop())
        for b in mutations:
            disk=ModelDisk();check(refuses(lambda:stream(b,g,tags,disk,64)));check(disk.partial is None and disk.final is None);check(refuses(lambda:ref.encode(b,g,*tags)));negative+=1;badshapes+=1
        low=dict(g,ceiling=len(data)-1);disk=ModelDisk();check(refuses(lambda:stream(s,low,tags,disk,64)));check(disk.partial is None);negative+=1
        for budget in [0,-1]:
            disk=ModelDisk();check(refuses(lambda:stream(s,g,tags,disk,budget)));check(disk.partial is None);negative+=1
        # Wrong transport bytes are refused independently of the emitter.
        for pos in [0,8,40,48,56,88,len(data)//2,len(data)-1]:
            bad=bytearray(data);bad[pos]^=1;check(refuses(lambda:ref.decode_equal(bad,s,g,*tags)));negative+=1
        for bad in [data[:-1],data+b'X']:
            check(refuses(lambda:ref.decode_equal(bad,s,g,*tags)));negative+=1
        # Preserve representation, do not silently reduce an invalid field.
        noncanonical=copy.deepcopy(s);noncanonical['slots'][0]['scalar']=(ref.P,0)
        nd=ModelDisk();stream(noncanonical,g,tags,nd,64);check(nd.final==ref.encode(noncanonical,g,*tags));check(refuses(lambda:ref.decode_equal(nd.final,noncanonical,g,*tags)));negative+=1
        if z==0 and k==l-1:
            name=f'l{l}-k{k}';(E/'fixtures').mkdir(exist_ok=True)
            (E/'fixtures'/f'{name}.json').write_text(json.dumps(dict(g=g,s=s,tags=[x.hex() for x in tags]))+'\n')
            (E/'fixtures'/f'{name}.bin').write_bytes(data);saved.append(name)
    # Real bounded research-only filesystem smoke; no private data or proof.
    folder=E/'files';folder.mkdir(exist_ok=True)
    with (folder/'stream.partial').open('wb',buffering=0) as f:
        w=c.ChunkWriter(f,1024);size,digest=c.emit_segment(s,g,*tags,w);os.fsync(f.fileno())
    os.replace(folder/'stream.partial',folder/'stream.bin')
    (folder/'reference.bin').write_bytes(data)
    check((folder/'stream.bin').read_bytes()==data);check(digest==hashlib.sha256(data).hexdigest())
    # Source-only owner/lifetime facts, with immutable local snapshots.
    root=Path('/home/victor/IntelligenceRegulation'); native=E/'native';native.mkdir(exist_ok=True)
    paths=['hashline/src/private_block/run.rs','hashline/src/private_block/protocol.rs','hashline/src/private_block/wire.rs','hashline/src/private_block/run_sink.rs','hashline/src/private_block/trained_block.rs','hashline/src/zk.rs','zkp-core/src/pcs.rs','zkp-core/src/sumcheck.rs']
    pins=[]
    for p in paths:
        source=root/'ops/zkp-mvp/trained-1b'/p;b=source.read_bytes();name=p.replace('/','__');(native/name).write_bytes(b);pins.append(dict(path=str(source),snapshot='native/'+name,sha256=hashlib.sha256(b).hexdigest(),bytes=len(b)))
    (E/'native-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
    run=(native/'hashline__src__private_block__run.rs').read_text();proto=(native/'hashline__src__private_block__protocol.rs').read_text();wire=(native/'hashline__src__private_block__wire.rs').read_text();sink=(native/'hashline__src__private_block__run_sink.rs').read_text()
    facts={
      'core_owners_already_drop':all(proto.index(f'drop({x});')<proto.index('Ok(CoreProof {') for x in ['wit','looked','mc','a','h']),
      'segment_drops_before_sink':run.index('drop(seg);')<run.index('sink(k, bytes)?;'),
      'sink_precedes_boundary_move':run.index('sink(k, bytes)?;')<run.index('prev = cur;'),
      'one_full_segment_vec': 'let mut out = Vec::with_capacity(len);' in wire[wire.index('pub(crate) fn encode_segment'):],
      'run_encode_has_no_decode': 'decode_segment(' not in wire[wire.index('pub(crate) fn encode_segment'):wire.index('/// Decode segment')],
      'sink_sync_rename_hash_order':sink.index('f.sync_all()')<sink.index('fs::rename(')<sink.index('self.digests.push(digest_hex(&bytes))'),
      'native_sink_owned_vec':'fn accept(&mut self, k: usize, bytes: Vec<u8>)' in sink,
    }
    for v in facts.values():check(v)
    (E/'source-facts.json').write_text(json.dumps(facts,indent=2)+'\n')
    (E/'wire-counts.json').write_text(json.dumps(results,indent=2)+'\n')
    result=dict(status='PASS',seed=SEED,checks=checks,negative_controls=negative,fixtures=21,stream_variants=len(results),fault_cases=faults,shape_mutations=badshapes,saved_fixtures=saved,native_source_pins=len(pins),source_facts=len(facts),wire_bytes_min=min(x['bytes'] for x in results),wire_bytes_max=max(x['bytes'] for x in results),proofs=0,complete_model_passes=0,proved_positions=0,native_execution=False,actual_peak_or_speed=None,wall_s=time.monotonic()-started)
    (E/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
if __name__=='__main__':main()
