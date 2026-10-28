"""Shieldstral S2 arithmetic conversion from the dg base, before native R13 load.

The emitted manifest is an evaluator artifact, NOT an accepted native export.
Keep c2 numerator multipliers and public group exponents explicit. The group
activation scale is applied before product rounding, exactly as fp_lib.rx_block.
"""
import numpy as np
import calibration_port as P
from signed_word_domain import DOMAIN

BITS={'q':5,'k':5,'v':6,'o':8,'g':6,'u':4,'d':6}
MODS=frozenset(('y8','fp12','a8','ah2','g4','h8'))


def real_words(W,Lw,diag):
    """Recover exact solver scales from saved diag arrays, without inverse fitting.

Orientations match fp_lib.real_weights. All matrices are public. Float32 storage
matches that tool; this controls quantization, not integer relation arithmetic.
"""
    c=Lw['c'];out={}
    fa=W['input_layernorm.weight'].astype(np.float64)*diag['ya']
    fm=W['post_attention_layernorm.weight'].astype(np.float64)*diag['ym']
    for site in ('q','k','v'):
        weight=W[f'self_attn.{site}_proj.weight'].astype(np.float64)*fa[None,:]
        scale=diag[site]/2.0**int(c['sh_qkv'])
        out['w'+site]=(weight/scale[:,None]).astype(np.float32)
    scale=diag['s_x']/(2.0**int(c['sh_ao'])*diag['o'])
    out['wo']=(W['self_attn.o_proj.weight']/scale[None,:]).astype(np.float32)
    gate_scale=diag['gate']/2.0**int(c['sh_g'])
    out['wg_t']=((W['mlp.gate_proj.weight']*fm[None,:])/gate_scale).T.astype(np.float32)
    up_scale=diag['u']/2.0**int(c['sh_u'])
    out['wu_t']=((W['mlp.up_proj.weight']*fm[None,:])/up_scale[:,None]).T.astype(np.float32)
    down_scale=diag['s_x_out']/(2.0**int(c['sh_z'])*diag['h'])
    out['wd_t']=(W['mlp.down_proj.weight']/down_scale[None,:]).T.astype(np.float32)
    return {k:np.ascontiguousarray(v) for k,v in out.items()}


def group_tables(ej,eoj):
    """Exactly the g4 lookup used by rx_block: int12 input, int16 output."""
    members=sorted(set(zip(map(int,ej),map(int,eoj))))
    if len(members)>4:raise ValueError('more than four group tables')
    ids=np.asarray([members.index((int(e),int(o))) for e,o in zip(ej,eoj)],dtype=np.int64)
    tables=[]
    for ein,eout in members:
        x=np.arange(-2048,2048,dtype=np.float64)*2.0**(ein-4)
        with np.errstate(over='ignore'):
            values=x/(1+np.exp(-x))/2.0**eout
        tables.append(np.clip(np.floor(values+.5),-32767,32767).astype(np.int16))
    return members,ids,np.asarray(tables)


def common_shift(effective_shifts):
    """One nonnegative denominator and exact public power-of-two numerators."""
    shifts=np.asarray(effective_shifts,dtype=np.int64)
    common=max(0,int(shifts.max()))
    powers=common-shifts
    if common>24 or np.any(powers>30):raise ValueError('group denominator/coefficient outside provisional R13 bounds')
    return common,np.left_shift(np.ones_like(powers),powers)


def convert(Lw,Wreal,statistics):
    words,mult,report=P.fl.apply_multipliers(Lw,Wreal,BITS)
    ej,eoj,tabs,sat,groups=P.fl.gate_groups(statistics,-5,mc=8,m2=4,sat=False,ngroups=4)
    members,gids,tables=group_tables(ej,eoj)
    c=Lw['c'];ein,eout=c['silu']
    # Effective gate denominator includes the group input step and c2 bits.
    gbits=mult.get('g',(None,0))[1]
    gshift,gfactor=common_shift(int(c['sh_g'])+8-4+gbits+ej-int(ein))
    hshift,hfactor=common_shift(int(c['sh_h'])-8-(eoj-int(eout)))
    actual={site:int(mult[site][1]) if site in mult else 0 for site in BITS}
    meta={'schema':'zk60-shieldstral-s2-evaluator/1','status':'candidate arithmetic; native R13 schema/acceptance pending',
          'mods':sorted(MODS),'mult_bits':actual,'requested_mult_bits':BITS,'mult_report':report,'group_report':groups,
          'group_members':members,'gate_common_shift':gshift,'product_common_shift':hshift,
          'group_scale_order':'activation scale BEFORE product rounding',
          'word_domain_amendment':DOMAIN,
          'scope':'evaluation input; not proof or privacy acceptance'}
    extra={'group_ids':gids,'group_tables':tables,'group_input_exponents':ej,'group_output_exponents':eoj,
           'gate_group_coefficients':gfactor,'product_group_coefficients':hfactor}
    for site,(m,b) in mult.items():extra['mult_'+site]=m.astype(np.int64)
    return {'w':words,'c':c,'manifest':Lw.get('manifest',{})},mult,(ej,eoj,tabs,sat),meta,extra


def evaluator(Lw,T,statistics,Wreal):
    converted,mult,groups,meta,extra=convert(Lw,Wreal,statistics)
    model=P.fl.LayerModel(converted,T,mods=MODS)
    model.mult=mult;model.gate_pc=groups
    return model,meta,extra
