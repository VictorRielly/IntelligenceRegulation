"""Independent descriptor-driven contiguous encoder and strict wire reader.
Does not import candidate.py. This is transport checking, never proof checking.
"""
import struct
P=18446744069414584321

def schema(g):
    """Build descriptors solely from the caller's own geometry."""
    desc=[('magic','raw',8),('binding','raw',32),('l','u',1),('k','u',1),('start','raw',32)]
    if g['k']!=g['l']-1:desc += [('b','raw',32)]
    desc += [(x,'raw',32) for x in ['aroot','hroot','mroot']]
    for i,(rounds,degree,terms) in enumerate(g['slots']):
        desc += [(('slots',i,'scalar'),'f',2)]
        desc += [(('slots',i,'rounds',j),'f',2*(degree+1)) for j in range(rounds)]
        desc += [(('slots',i,'terms'),'f',2*terms)]
    def columns(prefix,rows,width,path):
        for q in range(g['q']):
            base=(*prefix,'cols',q)
            desc.extend([(base+(0,),'index',width),(base+(1,),'f',rows),(base+(2,),'raw',32)])
            desc.extend([(base+(3,j),'raw',32) for j in range(path)])
    desc += [(('mask',n),'f',2048) for n in ['q','prox']]
    columns(('mask',),g['mr'],4096,12)
    roles=[('a',g['ag'],g['ar'],g['n']),('h',g['hg'],g['hr'],g['n']),('in',1 if g['k']==0 else g['sites'],g['er'] if g['k']==0 else g['br'],g['en'])]
    if g['k']==g['l']-1:roles.append(('out',1,g['er'],g['en']))
    for name,groups,rows,n in roles:
        desc.extend([((name,'groups',i),'f',2*(n+g['q'])) for i in range(groups)])
        desc.append(((name,'prox'),'f',2*(n+g['q'])))
        columns((name,),rows,n*g['rate'],(n*g['rate']).bit_length()-1)
    return desc+[('end','raw',32)]

def get(s,key):
    if isinstance(key,str):return s[key]
    for k in key:s=s[k]
    return s

def flat(x):
    if isinstance(x,int):return [x]
    return [v for a in x for v in flat(a)]

def encode(s,g,binding,start,end):
    if len(s['slots'])!=len(g['slots']):raise ValueError('slot count')
    if any(len(sp['rounds'])!=shape[0] for sp,shape in zip(s['slots'],g['slots'])):raise ValueError('round count')
    if (s['b'] is None)!=(g['k']==g['l']-1) or (s['out'] is not None)!=(g['k']==g['l']-1):raise ValueError('schedule')
    roles=[('a',g['ag']),('h',g['hg']),('in',1 if g['k']==0 else g['sites'])]+([('out',1)] if g['k']==g['l']-1 else [])
    if any(len(s[name]['groups'])!=groups or len(s[name]['cols'])!=g['q'] for name,groups in roles) or len(s['mask']['cols'])!=g['q']:raise ValueError('opening count')
    data=dict(s,magic=b'HLPRUNS1',binding=binding,l=g['l'],k=g['k'],start=start,end=end)
    pieces=[]
    for key,kind,n in schema(g):
        x=get(data,key)
        if kind=='raw':
            if len(x)!=n:raise ValueError('raw size')
            pieces.append(x)
        else:
            vals=flat(x)
            if len(vals)!=(1 if kind=='index' else n):raise ValueError('shape')
            if kind=='index' and not 0<=vals[0]<n:raise ValueError('index')
            pieces.append(struct.pack('<'+'Q'*len(vals),*vals))
    result=b''.join(pieces)
    if len(result)>g['ceiling']:raise ValueError('ceiling')
    return result

def decode_equal(data,s,g,binding,start,end):
    original=dict(s,magic=b'HLPRUNS1',binding=binding,l=g['l'],k=g['k'],start=start,end=end)
    pos=0
    for key,kind,n in schema(g):
        size=n if kind=='raw' else 8*(1 if kind=='index' else n)
        b=data[pos:pos+size];pos+=size
        if len(b)!=size:raise ValueError('truncated')
        want=get(original,key)
        if kind=='raw':
            if b!=want:raise ValueError('bytes')
        else:
            values=struct.unpack('<'+'Q'*(size//8),b)
            if kind=='f' and any(x>=P for x in values):raise ValueError('noncanonical')
            if kind=='index' and values[0]>=n:raise ValueError('index')
            if list(values)!=flat(want):raise ValueError('value/order')
    if pos!=len(data):raise ValueError('trailing')
    return True
