"""Public synthetic signed-byte padding oracle. No model data or native proof."""
import hashlib
import json
import os
from pathlib import Path
import platform
import random
import resource
import signal
import struct
import time

HERE = Path(__file__).resolve().parent
SEED = 2026101987
checks = 0
controls = {}


def check(ok):
    global checks
    assert ok
    checks += 1


def limits():
    resource.setrlimit(resource.RLIMIT_AS, (512 * 1024**2,) * 2)
    resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
    signal.alarm(59)
    os.nice(19)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})


def p2(n):
    return 1 << (n - 1).bit_length()


def map_q(s, j):
    h, lane = divmod(j, s['hd'])
    group = s['qh'] // s['kv']
    return ((h // group) * (s['hp'] // s['kv']) + h % group) * s['hd'] + lane


def specs(s):
    d, f, dp, fp, k = s['qh']*s['hd'], s['f'], s['hp']*s['hd'], p2(s['f']), s['kv']*s['hd']
    return [('wq',d,d,dp,dp,'q','i'), ('wk',k,d,k,dp,'i','i'),
            ('wv',k,d,k,dp,'i','i'), ('wo',d,d,dp,dp,'i','q'),
            ('gamma_a',1,d,1,dp,'i','i'), ('gamma_m',1,d,1,dp,'i','i'),
            ('wg',d,f,dp,fp,'i','i'), ('wu',d,f,dp,fp,'i','i'),
            ('wd',f,d,fp,dp,'i','i')]


def admission(raw, nr, nc, dtype='int8', shape=None):
    # Synthetic prevalidation wrapper, not native exact error messages.
    # pad_i8_bytes itself requires native load_array_checked's validated input.
    if dtype != 'int8':
        return 'dtype'
    if shape is not None and list(shape) != [nr,nc]:
        return 'shape'
    if len(raw) != nr*nc:
        return 'length'
    return None


def direct(raw, nr, nc, pr, pc, om, im, bug=None):
    """Port of destination-row traversal; no complete signed decode buffer."""
    if bug == 'prefix':
        om, im = list(range(nr)), list(range(nc))
    src_of = [None] * pr
    for o in range(nr):
        src_of[om[o]] = o
    identity = all(i == j for i,j in enumerate(im))
    out = [0] * (pr*pc)
    for r,o in enumerate(src_of):
        if o is None:
            continue
        for i in range(nc):
            # Source-row stride is TRUE input width; destination is padded.
            ix = o * (pc if bug == 'source_stride' else nc) + i
            v = raw[ix] if ix < len(raw) else 0
            if bug != 'unsigned' and v >= 128:
                v -= 256
            dst = r*pc + (i if identity else im[i])
            out[dst] = v
    if bug == 'pad_nonzero':
        used = {r*pc+c for r in om for c in im}
        for i in range(len(out)):
            if i not in used:
                out[i] = -1
                break
    return out


def reference(raw, nr, nc, pr, pc, om, im):
    """Independent complete signed decode then per-destination inversion."""
    signed = struct.unpack('<'+'b'*len(raw), raw)
    inverse_o = dict(zip(om,range(nr)))
    inverse_i = dict(zip(im,range(nc)))
    return [signed[inverse_o[r]*nc+inverse_i[c]] if r in inverse_o and c in inverse_i else 0
            for r in range(pr) for c in range(pc)]


def wrapped(fn, raw, spec, om, im, dtype='int8', shape=None):
    _,nr,nc,pr,pc,_,_ = spec
    error = admission(raw,nr,nc,dtype,shape)
    if error:
        return error, None
    return None, fn(raw,nr,nc,pr,pc,om,im)


def reject(name, ok):
    check(ok)
    controls[name] = controls.get(name,0)+1


def run():
    limits()
    start=time.perf_counter()
    rng=random.Random(SEED)
    fixtures=[]
    seen=set()
    shapes=[(2,1,2,5),(6,2,2,11),(12,4,2,19),(8,2,2,16),
            (3,1,4,9),(12,4,4,25),(4,2,4,17),(16,4,2,31)]
    for rep in range(6):
        for qh,kv,hd,f in shapes:
            s=dict(qh=qh,kv=kv,hd=hd,f=f,hp=p2(qh))
            matrices=[]
            for spec in specs(s):
                name,nr,nc,pr,pc,ra,ca=spec
                om=[map_q(s,i) if ra=='q' else i for i in range(nr)]
                im=[map_q(s,i) if ca=='q' else i for i in range(nc)]
                if rep==0:
                    raw=bytes((i*73+129)%256 for i in range(nr*nc))
                elif rep==1:
                    raw=bytes([128,255,0,127,1,129][i%6] for i in range(nr*nc))
                elif rep==2:
                    raw=bytes((i//nc*19+i%nc*41+131)%256 for i in range(nr*nc))
                else:
                    raw=bytes(rng.randrange(256) for _ in range(nr*nc))
                seen.update(raw)
                a=wrapped(direct,raw,spec,om,im)
                b=wrapped(reference,raw,spec,om,im)
                check(a==b and a[0] is None)
                values=a[1]
                check(all(-128<=v<=127 for v in values))
                check(raw==bytes((i&255) for i in struct.unpack('<'+'b'*len(raw),raw)))
                packed=struct.pack('<'+'b'*len(values),*values)
                check(len(packed)==pr*pc)
                used={r*pc+c for r in om for c in im}
                check(all(values[i]==0 for i in range(pr*pc) if i not in used))
                for bad,label in [(raw[:-1],'short'),(raw+b'\x00','long')]:
                    reject(label, wrapped(direct,bad,spec,om,im)==wrapped(reference,bad,spec,om,im)==('length',None))
                reject('dtype_before_length',wrapped(direct,b'',spec,om,im,dtype='int16')==('dtype',None))
                reject('shape_before_length',wrapped(direct,b'',spec,om,im,shape=[nc,nr+1])==('shape',None))
                for bug in ['unsigned','prefix','source_stride','pad_nonzero']:
                    eligible = (bug=='unsigned' and any(x>=128 for x in raw)) or (bug=='prefix' and (om!=list(range(nr)) or im!=list(range(nc)))) or (bug=='source_stride' and pc!=nc and nr>1) or (bug=='pad_nonzero' and len(used)<pr*pc)
                    if eligible:
                        reject(bug,direct(raw,nr,nc,pr,pc,om,im,bug)!=values)
                matrices.append(dict(name=name,dims=[nr,nc,pr,pc],axes=[ra,ca],raw_hex=raw.hex(),signed=values,encoded_sha256=hashlib.sha256(packed).hexdigest()))
            fixtures.append(dict(shape=s,matrices=matrices))
    check(seen==set(range(256)))
    # Exhaustive byte sweep through identity and non-identity column maps.
    sweeps=[]
    raw=bytes(range(256))
    for om,im,pr,pc in [(list(range(8)),list(range(32)),8,32),
                       ([0,1,2,4,5,6,8,9],list(range(32)),16,64),
                       (list(range(8)),list(range(0,64,2)),8,64)]:
        a=direct(raw,8,32,pr,pc,om,im);b=reference(raw,8,32,pr,pc,om,im)
        check(a==b)
        for k in range(256):
            r,c=divmod(k,32)
            check(a[om[r]*pc+im[c]]==int.from_bytes(raw[k:k+1],'little',signed=True))
        sweeps.append(dict(raw_hex=raw.hex(),dims=[8,32,pr,pc],om=om,im=im,signed=a))
    (HERE/'fixtures.json').write_text(json.dumps(fixtures,separators=(',',':'))+'\n')
    (HERE/'byte-sweeps.json').write_text(json.dumps(sweeps,separators=(',',':'))+'\n')
    result=dict(status='PASS',run_id='20261019T191854Z-6444ea2f',seed=SEED,checks=checks,
                layouts=len(fixtures),matrix_cases=sum(len(x['matrices']) for x in fixtures),
                exhaustive_byte_sweeps=len(sweeps),controls=controls,wall_seconds=time.perf_counter()-start,
                rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,
                affinity=sorted(os.sched_getaffinity(0)),nice=os.nice(0),python=platform.python_version(),
                cpu=next(l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),
                platform=platform.platform(),scope='Synthetic exact signed layout, source stride, zero pads and prevalidation only; no native proof or timing gain.',
                limits='59s wall/CPU,512MiB AS,one nice19 CPU; estimated64MiB; no native/GPU/build')
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))


if __name__=='__main__':
    run()
