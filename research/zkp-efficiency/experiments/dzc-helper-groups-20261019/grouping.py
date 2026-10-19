"""Public-DAG cuts; runtime values never participate in scheduling."""
import collections


def partition(q, minimum=48, maximum=80):
    ns=q.ops; n=len(ns)
    last={x['id']:x['id'] for x in ns}
    for x in ns:
        for d in x['deps']:last[d]=x['id']
    for d in q.output:last[d]=n
    cuts=[0]
    while cuts[-1]<n:
        lo=cuts[-1]
        if n-lo<=maximum:cuts.append(n);break
        # Minimize crossing storage, then favor a larger bounded group.
        choices=range(lo+minimum,min(n,lo+maximum)+1)
        cut=min(choices,key=lambda c:(sum(x['words'] for x in ns[:c] if last[x['id']]>=c),-c))
        cuts.append(cut)
    owner={i:k for k,(a,b) in enumerate(zip(cuts,cuts[1:])) for i in range(a,b)}
    groups=[];slots={};active={};capacity=0
    for k,(a,b) in enumerate(zip(cuts,cuts[1:])):
        ins=sorted({d for x in ns[a:b] for d in x['deps'] if d<a})
        outs=[x['id'] for x in ns[a:b] if last[x['id']]>=b]
        assert all(ns[d]['kind']!='load_base' for d in ins+outs), 'base crossings need their own typed slots'
        # Every input is loaded before output stores; dying input slots can
        # therefore be reused at this boundary without overwriting live data.
        active={d:s for d,s in active.items() if last[d]>=b}
        for d in outs:
            used=set(active.values());slot=next(s for s in range(capacity+1) if s not in used)
            capacity=max(capacity,slot+1);slots[d]=slot;active[d]=slot
        groups.append(dict(index=k,start=a,end=b,inputs=ins,outputs=outs))
    # Final values have no later group; explicitly store them into out.
    assert set(q.output)<=set(slots)
    return dict(groups=groups,slots=slots,capacity=capacity,cuts=cuts,
                crossing_loads=sum(len(g['inputs']) for g in groups),
                crossing_stores=sum(len(g['outputs']) for g in groups),
                max_group_ops=max(g['end']-g['start'] for g in groups))


def emit(q,name):
    plan=partition(q); slots=plan['slots'];ns=q.ops;body=[]
    for g in plan['groups']:
        k=g['index'];lines=[f'#[inline(never)] unsafe fn helper_{k}(raw:*const Gp2, params:*const Gp2, bases:*const u64, scratch:*mut Gp2) {{']
        lines += [f' let s{d} = *scratch.add({slots[d]});' for d in g['inputs']]
        for x in ns[g['start']:g['end']]:
            kind=x['kind'];i=x['id'];ds=x['deps']
            if kind.startswith('load_'):
                src={'load_raw':'raw','load_param':'params','load_base':'bases'}[kind]
                rhs=f'*{src}.add({x["slot"]})'
            else:
                method={'add':'add','sub':'sub','mul':'mul','base':'mul_base'}[kind]
                rhs=f's{ds[0]}.{method}(s{ds[1]})'
            lines.append(f' let s{i} = {rhs};')
        lines += [f' *scratch.add({slots[d]}) = s{d};' for d in g['outputs']]
        body.append('\n'.join(lines+['}']))
    body.append(f'#[no_mangle] pub unsafe extern "C" fn {name}(raw:*const Fp2, params:*const Fp2, bases:*const u64, out:*mut Fp2) {{')
    body.append(f' let mut storage = core::mem::MaybeUninit::<[Gp2;{plan["capacity"]}]>::uninit();')
    body.append(' let scratch=storage.as_mut_ptr() as *mut Gp2;')
    for g in plan['groups']:
        body.append(f' helper_{g["index"]}(raw as *const Gp2, params as *const Gp2, bases, scratch);')
    for i,d in enumerate(q.output):body.append(f' *(out as *mut Gp2).add({i}) = *scratch.add({slots[d]});')
    body.append('}')
    return '\n'.join(body)


GROUP_HEADER='''
#[repr(C)] #[derive(Clone,Copy)] struct Gp2 {a:u64,b:u64}
impl Gp2 {
 #[inline(always)] fn inner(self)->native::Fp2 {native::Fp2::new(native::Fp(self.a),native::Fp(self.b))}
 #[inline(always)] fn from(v:native::Fp2)->Self {Self{a:v.c0.0,b:v.c1.0}}
 #[inline(always)] fn add(self,o:Self)->Self {Self::from(self.inner().add(o.inner()))}
 #[inline(always)] fn sub(self,o:Self)->Self {Self::from(self.inner().sub(o.inner()))}
 #[inline(always)] fn mul(self,o:Self)->Self {Self::from(self.inner().mul(o.inner()))}
 #[inline(always)] fn mul_base(self,o:u64)->Self {Self::from(self.inner().mul_base(native::Fp(o)))}
}
'''
