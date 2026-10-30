import hashlib, json, pathlib, struct
D=pathlib.Path(__file__).resolve().parent
P=0xffffffff00000001
checks=0
def check(x):
    global checks
    assert x
    checks+=1
def independent(v):
    rows,n,k=v['rows'],v['n'],v['k']
    # Unbounded whole sums reduce only after accumulating a complete output limb.
    out=[]
    for g in range(k):
        for j in range(n):
            for limb in (0,1):
                out.append(sum(v['rho'][g][2*i+limb]*v['data'][i*n+j] for i in range(rows))%P)
    # Independently serialize little-endian scalar limbs, never Fp2 structure bytes.
    wire=b''.join(struct.pack('<Q',x) for rho in v['rho'] for x in rho)
    return list(struct.unpack('<'+'Q'*(len(wire)//8),wire)),out
vectors=[json.loads(s) for s in (D/'public-vectors.jsonl').read_text().splitlines()]
packed_limbs=output_limbs=0
for v in vectors:
    want,out=independent(v)
    check(want==v['packed']);check(out==v['out'])
    check(len(want)==2*v['rows']*v['k']);check(len(out)==2*v['n']*v['k'])
    packed_limbs+=len(want);output_limbs+=len(out)
counts=[json.loads(s) for s in (D/'allocation-counts.jsonl').read_text().splitlines()]
for v in counts:
    r,k=v['rows'],v['k'];nz=int(r!=0)
    check(v['baseline_allocs']==(k+1)*nz);check(v['direct_allocs']==nz)
    check(v['baseline_requested_B']==32*k*r);check(v['direct_requested_B']==16*k*r)
    check(v['baseline_peak_B']==16*(k+1)*r);check(v['direct_peak_B']==16*k*r)
    check(v['direct_capacity_limbs']>=2*k*r)
plans=[json.loads(s) for s in (D/'public-length-plans.jsonl').read_text().splitlines()]
for v in plans:
    n=2*v['k']*v['rows']
    expected=n if n<=((1<<63)-1)//8 else None
    check(v['limbs']==expected)
base=next(v for v in vectors if v['rows']==7 and v['k']==4 and v['mode']==0)
negative=[]
for kind in ['limb_swap','vector_reverse','last_vector_omitted','last_limb_changed','split_limb_layout']:
    v=json.loads(json.dumps(base))
    if kind=='limb_swap':
        for rho in v['rho']:
            for i in range(0,len(rho),2):rho[i],rho[i+1]=rho[i+1],rho[i]
    elif kind=='vector_reverse':v['rho'].reverse()
    elif kind=='last_vector_omitted':v['rho'].pop();v['k']-=1
    elif kind=='last_limb_changed':v['rho'][-1][-1]=(v['rho'][-1][-1]+1)%P
    else:
        for g,rho in enumerate(v['rho']):v['rho'][g]=rho[::2]+rho[1::2]
    packed,out=independent(v)
    check(packed!=base['packed']);check(out!=base['out']);negative.append(kind)
pins=json.loads((D/'source-pins.json').read_text())
for p in pins:check(hashlib.sha256((D/p['snapshot']).read_bytes()).hexdigest()==p['sha256'])
patch=(D/'direct-pack-review-only.patch').read_text()
check(patch.count('@@')==2);check('-        flat.extend(as_u64s_f2(rho));' in patch)
check('+            flat.push(x.c0.0);' in patch);check('+            flat.push(x.c1.0);' in patch)
rust=json.loads((D/'rust-result.json').read_text())
check(rust['fixtures']==len(counts));check(rust['exported_vectors']==len(vectors));check(rust['length_plans']==len(plans))
r=dict(status='PASS',rust=rust,python_assertions=checks,python_bigint_vectors=len(vectors),python_packed_limbs=packed_limbs,
    python_bigint_output_limbs=output_limbs,python_negative_controls=negative,allocation_fixtures=len(counts),length_plans=len(plans),
    scope='Optimized instrumented CPU host packing and exact scalar host-fold only; no CUDA, transcript, receipt, full-stack proof or privacy acceptance',
    full_stack_proofs=0,passes=0,positions=0)
(D/'result.json').write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps(r))
