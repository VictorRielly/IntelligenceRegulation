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


def emit_unique(q,name):
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


def shared_plan(q):
    """Address-independent topology; retain exact concrete maps per instance."""
    import json
    plan = partition(q)
    classes = []
    keys = []
    for g in plan['groups']:
        ids = g['inputs'] + list(range(g['start'], g['end']))
        local = {d: j for j, d in enumerate(ids)}
        ops = q.ops[g['start']:g['end']]
        shape = dict(inputs=len(g['inputs']),
                     ops=[dict(kind=x['kind'], deps=[local[d] for d in x['deps']]) for x in ops],
                     outputs=[local[d] for d in g['outputs']])
        key = json.dumps(shape, sort_keys=True)
        if key not in keys:
            keys.append(key)
            classes.append(dict(shape=shape, instances=[]))
        ci = keys.index(key)
        classes[ci]['instances'].append(g['index'])
        g['template'] = ci
        slots = plan['slots']
        g['map'] = ([slots[d] for d in g['inputs']] +
                    [x['slot'] for x in ops if x['kind'].startswith('load_')] +
                    [slots[d] for d in g['outputs']])
        assert all(0 <= x < 65536 for x in g['map'])
    plan['templates'] = classes
    plan['map_entries_per_row'] = sum(len(g['map']) for g in plan['groups']
                                      if len(classes[g['template']]['instances']) > 1)
    plan['map_bytes'] = 2 * plan['map_entries_per_row']
    return plan


def emit(q, name):
    plan = shared_plan(q)
    body = []
    for ci, cls in enumerate(plan['templates']):
        g = plan['groups'][cls['instances'][0]]
        shared = len(cls['instances']) > 1
        ids = g['inputs'] + list(range(g['start'], g['end']))
        local = {d: j for j, d in enumerate(ids)}
        arg = ', map:*const u16' if shared else ''
        lines = [f'#[inline(never)] unsafe fn template_{ci}(raw:*const Gp2, params:*const Gp2, bases:*const u64, scratch:*mut Gp2{arg}) {{']
        mi = 0
        def address():
            nonlocal mi
            result = f'(*map.add({mi}) as usize)' if shared else str(g['map'][mi])
            mi += 1
            return result
        for d in g['inputs']:
            lines.append(f' let s{local[d]} = *scratch.add({address()});')
        for x in q.ops[g['start']:g['end']]:
            kind = x['kind']
            if kind.startswith('load_'):
                src = {'load_raw':'raw', 'load_param':'params', 'load_base':'bases'}[kind]
                rhs = f'*{src}.add({address()})'
            else:
                method = {'add':'add', 'sub':'sub', 'mul':'mul', 'base':'mul_base'}[kind]
                a, b = [local[d] for d in x['deps']]
                rhs = f's{a}.{method}(s{b})'
            lines.append(f' let s{local[x["id"]]} = {rhs};')
        for d in g['outputs']:
            lines.append(f' *scratch.add({address()}) = s{local[d]};')
        assert mi == len(g['map'])
        body.append('\n'.join(lines + ['}']))
    for g in plan['groups']:
        if len(plan['templates'][g['template']]['instances']) > 1:
            vals = ','.join(str(x) for x in g['map'])
            body.append(f'static MAP_{g["index"]}:[u16;{len(g["map"])}]=[{vals}];')
    body += [f'#[no_mangle] pub unsafe extern "C" fn {name}(raw:*const Fp2, params:*const Fp2, bases:*const u64, out:*mut Fp2) {{',
             f' let mut storage=core::mem::MaybeUninit::<[Gp2;{plan["capacity"]}]>::uninit();',
             ' let scratch=storage.as_mut_ptr() as *mut Gp2;']
    for g in plan['groups']:
        shared = len(plan['templates'][g['template']]['instances']) > 1
        arg = f', MAP_{g["index"]}.as_ptr()' if shared else ''
        body.append(f' template_{g["template"]}(raw as *const Gp2, params as *const Gp2, bases, scratch{arg});')
    for i, d in enumerate(q.output):
        body.append(f' *(out as *mut Gp2).add({i}) = *scratch.add({plan["slots"][d]});')
    body.append('}')
    # Negative control changes only an initialized, in-bounds parameter load.
    # Scratch input/output maps stay untouched, avoiding uninitialized reads.
    repeated = next(g for g in plan['groups']
                    if len(plan['templates'][g['template']]['instances']) > 1)
    mi = len(repeated['inputs'])
    loads = [x for x in q.ops[repeated['start']:repeated['end']]
             if x['kind'].startswith('load_')]
    assert loads[0]['kind'] == 'load_param'
    bad = repeated['map'][:]
    bad[mi] = (bad[mi] + 1) % len(q.params)
    body.append(f'static BAD_MAP:[u16;{len(bad)}]=[{",".join(map(str,bad))}];')
    # Reuse the emitted templates; no second set of field helper bodies.
    # Build an explicit wrapper to keep the control independent of string slices.
    badbody = [f'#[no_mangle] pub unsafe extern "C" fn bad_map(raw:*const Fp2, params:*const Fp2, bases:*const u64, out:*mut Fp2) {{',
               f' let mut storage=core::mem::MaybeUninit::<[Gp2;{plan["capacity"]}]>::uninit();',
               ' let scratch=storage.as_mut_ptr() as *mut Gp2;']
    for g in plan['groups']:
        shared = len(plan['templates'][g['template']]['instances']) > 1
        mp = 'BAD_MAP' if g['index'] == repeated['index'] else f'MAP_{g["index"]}'
        arg = f', {mp}.as_ptr()' if shared else ''
        badbody.append(f' template_{g["template"]}(raw as *const Gp2, params as *const Gp2, bases, scratch{arg});')
    for i, d in enumerate(q.output):
        badbody.append(f' *(out as *mut Gp2).add({i}) = *scratch.add({plan["slots"][d]});')
    body.extend(badbody + ['}'])
    return '\n'.join(body)
