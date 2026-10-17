"""Public native-shaped SC_SZC capture adapter; no witness-derived layout.

The input is constructor captures, not a serialized/prover-supplied structure.
Unsupported metadata declines specialization and must retain the scalar path.
No per-row gather: graph input references are rewritten once to native indices.
"""
from dataclasses import dataclass
import re
from field_support import F
from generate import build, build_original, emit, rust_source


@dataclass(frozen=True)
class Capture:
    idx: tuple
    im: int
    imx: int
    isum: int
    ihx: int
    h0: int
    i_sr: tuple
    i_sg: tuple
    i_pl: tuple
    lks: tuple  # ((table index, base coefficient), ...) for each lookup
    n_help: int
    gs: object
    ght: object
    pad_on: bool
    splanes: tuple
    n_tabs: int


def carriers(cap):
    pairs=[('eq0',0),('eq1',1),('eq2',2),('mask',cap.im),
           ('s8',cap.idx[56]),('rsl',cap.idx[57]),('zsel',cap.idx[58]),
           ('e',cap.idx[59]),('p',cap.idx[60])]
    pairs += [(f'pl{i}',j) for i,j in enumerate(cap.i_pl)]
    pairs += [(f'sr{i}',j) for i,j in enumerate(cap.i_sr)]
    pairs += [(f'sg{i}',j) for i,j in enumerate(cap.i_sg)]
    pairs += [('mx',cap.imx),('sum',cap.isum)]
    pairs += [(f'h{i}',cap.h0+i) for i in range(cap.n_help)]+[('hx',cap.ihx)]
    if cap.ght is not None:pairs.append(('ght',cap.ght))
    if cap.gs is not None:pairs.append(('gs',cap.gs))
    indices=[i for _,i in pairs]
    if any(type(i) is not int or i<0 or i>=cap.n_tabs for i in indices):
        raise ValueError('capture index outside table frame')
    if len(set(indices))!=len(indices):raise ValueError('constructor carrier alias')
    if len(cap.i_sr)!=len(cap.i_sg) or not cap.i_sr or not cap.i_pl:
        raise ValueError('limb capture shape')
    if cap.n_help!=(len(cap.lks)+1)//2 or not cap.lks:
        raise ValueError('helper count')
    if not cap.pad_on and (cap.gs is not None or cap.ght is not None):
        raise ValueError('support without pad rule')
    return tuple(pairs)


def config(cap):
    pairs=carriers(cap);names=[n for n,_ in pairs];native=[i for _,i in pairs]
    reverse={i:j for j,i in enumerate(native)}
    lookups=[]
    for terms in cap.lks:
        if len(terms)!=1:raise ValueError('specialization requires one-term lookup')
        i,c=terms[0]
        if i not in reverse or type(c) is not int:raise ValueError('lookup capture')
        lookups.append((reverse[i],c,0))  # proof-local cst travels in offsets
    return dict(names=names,index={n:i for i,n in enumerate(names)},
                ls=len(cap.i_sr),lp=len(cap.i_pl),padded=cap.pad_on,
                supports=(cap.ght is not None,cap.gs is not None),
                lookups=lookups,helpers=cap.n_help,
                splanes=[reverse[i] for i in cap.splanes]),tuple(native)


def eligible(cap,round_index,mask_active):
    # pad_on may be true even if both optional supports are None. Its original
    # degree/profile metadata must not silently become an unpadded profile.
    carriers(cap)
    return (type(round_index) is int and round_index==0 and
            type(mask_active) is bool and not cap.pad_on and
            all(len(t)==1 for t in cap.lks))


def compile_capture(cap,mask_active,scheduled=True):
    if not eligible(cap,0,mask_active):raise ValueError('scalar fallback required')
    cfg,native=config(cap)
    graph,out=(build if scheduled else build_original)(cfg,mask_active)
    pattern=re.compile(r'(values|differences)\[(\d+)\]')
    def remap(x):
        return pattern.sub(lambda m:f'{m[1]}[{native[int(m[2])]}]',x)
    graph.nodes=[(op,remap(a),remap(b)) for op,a,b in graph.nodes]
    out=tuple(remap(x) for x in out)
    source,stats,_=emit(graph,out,True)
    scope={'F':F};exec(compile(source,'<local-native-capture-helper>','exec'),scope)
    # This key is entirely public. Constants and offsets stay per proof.
    key=(cap,mask_active,scheduled)
    return scope['factory'],source,stats,key,graph,out


def proof_arguments(cap,params):
    const={k:v for k,v in params.items() if k!='lk_cst'}
    offsets=tuple(params['alpha']-x for x in params['lk_cst'])
    if len(offsets)!=len(cap.lks):raise ValueError('proof-local lookup offsets')
    return const,offsets


def rust_artifact(graph,out):
    return rust_source(graph,out,'sc_szc_native_capture_round0')
