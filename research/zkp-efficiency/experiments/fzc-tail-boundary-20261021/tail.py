"""Authored source-level FZC tail model, never a native/GPU benchmark."""
import struct
P=2**64-2**32+1
Z=(0,0)
def add(a,b):return ((a[0]+b[0])%P,(a[1]+b[1])%P)
def sub(a,b):return ((a[0]-b[0])%P,(a[1]-b[1])%P)
def mul(a,b):
    ac=a[0]*b[0];bd=a[1]*b[1]
    return ((ac+7*bd)%P,((a[0]+a[1])*(b[0]+b[1])-ac-bd)%P)
def fold(a,b,r):return add(a,mul(r,sub(b,a)))
def enc(v):return b''.join(struct.pack('<QQ',*x) for x in v)

def fold_pack(tabs,k,stride,length,r,bug=None):
    assert 0<k and length>=4 and length%2==0 and stride>=length
    assert len(tabs)>=k*stride
    half=length//2;out=[None]*(k*half)
    for g in range(k*half):
        t,i=divmod(g,half)
        off=t*(half if bug=='packed_input_stride' else stride)+i
        a=tabs[off];b=tabs[off+(1 if bug=='adjacent_pairing' else half)]
        rr=(r[0],0) if bug=='drop_challenge_extension' else r
        v=fold(a,b,rr)
        out[g]=a if bug=='omit_fold' else (v[1],v[0]) if bug=='swap_coordinates' else v
    return out

def schedule(n,tail,k=21,degree=5,fused=True,split=True,mapped=True,profile=False,candidate=False):
    assert 1<=n<=26 and 0<=tail<=20 and k in (20,21)
    kd=k+(1+(k==21) if split else 0)
    length=1<<n;deferred=False;host=False;events=[]
    for j in range(n):
        if host:
            events.append(dict(round=j,kind='host_round',length=length,half=length//2))
            length//=2
            events.append(dict(round=j,kind='host_fold',outputs=k*length))
            continue
        if deferred:
            length//=2;deferred=False;kind='gpu_fused_round'
        else:kind='gpu_round'
        events.append(dict(round=j,kind=kind,length=length,launches=1+(not split),
                           copy_bytes=0 if split and mapped else 16*(degree+1),
                           syncs=int(not(split and mapped))+int(profile)))
        half=length//2;last=j+1>=n
        to_host=tail>0 and not last and half>=2 and half<=1<<tail
        if fused and not last and length>=4 and not to_host:
            deferred=True
        elif to_host and candidate:
            events.append(dict(round=j,kind='fold_pack',length=length,half=half,
                               launches=1,logical_bytes=48*k*half,fold_outputs=k*half,
                               syncs=int(profile)))
            length=half
        else:
            events.append(dict(round=j,kind='gpu_fold',length=length,half=half,
                               launches=1,logical_bytes=48*kd*half,fold_outputs=kd*half,
                               syncs=int(profile)))
            length=half
        if to_host:
            if not candidate:
                events.append(dict(round=j,kind='pack',launches=1,logical_bytes=32*k*half))
            events.append(dict(round=j,kind='tail_copy',copy_bytes=16*k*half,syncs=1,
                               half=half,device_alloc_bytes=16*k*half,pin_alloc_bytes=16*k*half))
            host=True
        if last:
            events.append(dict(round=j,kind='gpu_finals',launches=1,copy_bytes=16*k,syncs=1))
    assert length==1 and not deferred
    tail_copies=[x for x in events if x['kind']=='tail_copy']
    return dict(n=n,tail=tail,k=k,kd=kd,degree=degree,fused=fused,split=split,mapped=mapped,
                profile=profile,candidate=candidate,events=events,
                gpu_rounds=sum(e['kind'].startswith('gpu_') and 'round' in e['kind'] for e in events),
                host_rounds=sum(e['kind']=='host_round' for e in events),
                launches=sum(e.get('launches',0) for e in events),
                stream_or_profile_syncs=sum(e.get('syncs',0) for e in events),
                explicit_copy_bytes=sum(e.get('copy_bytes',0) for e in events),
                boundary_copy_bytes=sum(e['copy_bytes'] for e in tail_copies),
                boundary_length=tail_copies[0]['half'] if tail_copies else None,
                host_pairs=sum(e['half'] for e in events if e['kind']=='host_round'),
                host_fold_outputs=sum(e['outputs'] for e in events if e['kind']=='host_fold'),
                raw_eligible_if_resident=split and fused and n>=3 and n-1>tail)
