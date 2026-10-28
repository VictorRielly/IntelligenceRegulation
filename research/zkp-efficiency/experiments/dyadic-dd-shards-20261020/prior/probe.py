#!/usr/bin/env python3
"""Public, synthetic schedule/count oracle. Never makes or verifies a proof."""
import collections
import hashlib
import json
import math
import os
from pathlib import Path
import random
import resource
import signal
import struct
import sys
import time

HERE = Path(__file__).resolve().parent
sys.dont_write_bytecode = True
sys.path.insert(0, str(HERE / 'vendor/r11'))
import r11_activation_cost as r11
r10 = r11.r10
SEED = 20261020113
DEGREES = [3,3,3,4,3,2,2,2,2,2,2,2,2,2,4,4,4,4,4,3,2,2,2,4]
INDICATORS = {'SS':'D','SSM':'D','RS':'S','DZC':'D','QZC':'Q','KVZC':'Kv','SZC':'S','FZC':'F'}

def limits():
    resource.setrlimit(resource.RLIMIT_AS, (512 << 20, 512 << 20))
    resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
    signal.alarm(59)
    os.nice(19)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})

def exp_table(base_es, bits=12, fe=9):
    lam = 2.0 ** (base_es - (bits - 8)) / math.sqrt(128)
    return [math.floor((1 << fe) * math.exp(-d * lam) + .5) for d in range(1 << bits)]

def public_cap(values):
    n = len(set(values) | {0})
    return 1 << (n - 1).bit_length()

def make_layout(T, cap, high=True):
    geo = 'Llama-3-8B T%d' % T
    r10.DD_CAP = cap
    r10.F_P = 12 if high else 9
    cfg = r11.STACKS['WIDE'][1] if high else {}
    return r11.build(geo, cap > 0, cfg)[0]

def slot_schedule(lay):
    aa, hh = lay.claim_sites()
    slots = []
    for i, (name, main, ext, tables) in enumerate(lay.slot_work()):
        d = DEGREES[i] + int(name in INDICATORS and lay.pads[INDICATORS[name]])
        d += int(name in ('SCORE','PV') and lay.lkv > 0)
        terms = aa.get(name, 0) + hh.get(name, 0) + int(name in ('IO_IN','IO_OUT'))
        slots.append(dict(name=name, main=main, ext=ext, degree=d, terms=terms,
                          cfs_len=(main+ext)*d+2, tables=tables))
    return slots

def wire_parts(lay):
    """Parts whose deltas apply to a fixed run; excludes unchanged header/endpoints.

    Literal Shape::receipt_bytes skeleton. HIGH's new relations must still be
    reviewed to confirm these degrees/groups. New schedule metadata unpriced.
    """
    t = lay.totals()
    slots = slot_schedule(lay)
    n = lay.n
    tzc = len({(k * lay.t_pad) % n for k in range(9)})
    ag, hg = tzc + 27 + 2*lay.dd, 9 + lay.dd
    def opening(groups, rows):
        return (groups+1)*(n+256)*16 + 256*(8+rows*8+32+(lay.log_n+2)*32)
    slot_bytes = 16 * sum(1 + (s['main']+s['ext'])*(s['degree']+1)+s['terms'] for s in slots)
    mask_rows = 2*len(slots)+4
    mask_opening = 2*1024*16 + 256*(8+mask_rows*8+32+12*32)
    parts = dict(slots=slot_bytes, mask_opening=mask_opening,
                 a_opening=opening(ag,t['a_rows']), h_opening=opening(hg,t['h_rows']))
    # Exact selected M allocations/random draws in mask_commit_tagged. Does
    # not include PCS A/H pads, salts, private endpoints or run boundaries.
    cfs = sum(s['cfs_len'] for s in slots)
    return dict(parts=parts, total=sum(parts.values()), a_groups=ag, h_groups=hg,
                slot_count=len(slots), main_rounds=sum(s['main'] for s in slots),
                mask_rows=mask_rows, cfs_fp2_coeffs=cfs,
                M_fresh_base_words=2*cfs + 2*len(slots)*256 + 4*1024,
                M_encoded_bytes=mask_rows*4096*8,
                M_a_coefs_bytes=2*len(slots)*512*8,
                slots_detail=slots)

def record(T, cap):
    lay = make_layout(T,cap)
    t = lay.totals()
    return dict(context=T,cap=cap,totals=t,wire=wire_parts(lay),
                dictionary_A_bytes=0 if not cap else lay.a_planes()['Dd']*lay.size['Dd']*8,
                dictionary_H_bytes=0 if not cap else 2*lay.h_planes()['Dd']*lay.size['Dd']*8)

def cost_for(es, T, mode, uniform=None):
    cap = public_cap(exp_table(es))
    if mode == 'direct': cap = 0
    elif mode == 'uniform': cap = uniform
    elif mode == 'hybrid':
        if record(T,cap)['totals']['committed'] >= record(T,0)['totals']['committed']:
            cap = 0
    elif mode != 'layer': raise ValueError(mode)
    if cap and cap < public_cap(exp_table(es)): raise ValueError('public table over cap')
    return record(T,cap)

def lifetime(rows):
    """Selected dictionary payload scenarios; symbolic capacities, not native HWM.

    A exists before H and survives through its opening; H is prepared while A
    remains. Consecutive prove_core calls finish/open/drop A/H before the next.
    Independently retained largest role buffers model a conservative pool.
    """
    pairs = [(x['dictionary_A_bytes'], x['dictionary_H_bytes']) for x in rows]
    a = h = peak = total = 0
    events = []
    for k, (ar,hr) in enumerate(pairs):
        a,h=max(a,ar),max(h,hr)
        total += ar+hr
        peak=max(peak,a+h)
        events.append(dict(layer=k,A_requested=ar,H_requested=hr,A_capacity=a,H_capacity=h,
                           idle_capacity=a+h-ar-hr))
    return dict(exact_stream_peak=max((a+h for a,h in pairs), default=0),
                retained_all_layers=sum(a+h for a,h in pairs),
                role_pool_peak=peak, role_pool_final_capacity=a+h,
                cumulative_requested=total,events=events,
                exclusions='All other A/H owners and masks, PCS codewords/trees/pads, witness, looked/histogram, allocator/driver and transfers')

def aggregate(es, T, mode):
    uniform = max(public_cap(exp_table(e)) for e in es)
    rows = [cost_for(e,T,mode,uniform) for e in es]
    keys = ['committed','a_words','h_words','u8','a_mask_words','h_mask_words','element_terms','a_sites','h_sites']
    sums = {k:sum(r['totals'][k] for r in rows) for k in keys}
    wires = {k:sum(r['wire'][k] for r in rows) for k in ['total','slot_count','main_rounds','mask_rows','cfs_fp2_coeffs','M_fresh_base_words','M_encoded_bytes','M_a_coefs_bytes']}
    return dict(mode=mode,context=T,layers=len(es),cap_histogram=dict(collections.Counter(r['cap'] for r in rows)),
                totals=sums,wire=wires,lifetime=lifetime(rows),caps=[r['cap'] for r in rows])

def schedule_digest(es,caps,table_hashes):
    # Test interface only; not the production transcript/digest domain.
    b=json.dumps(dict(domain='research/public-DD-schedule/1',es=es,caps=caps,table_hashes=table_hashes),sort_keys=True).encode()
    return hashlib.sha256(b).hexdigest()

def run():
    limits(); start=time.perf_counter(); rng=random.Random(SEED); checks=0
    def check(ok):
        nonlocal checks
        checks+=1
        assert ok
    old=json.loads((HERE/'prior/result.json').read_text())
    oldcost=json.loads((HERE/'prior/cost-result.json').read_text())
    tables={}
    for e in range(5):
        vals=exp_table(e); cap=public_cap(vals)
        ref=next(c for c in old['cases'] if c['head_dim']==128 and c['f_e']==9 and c['bits']==12 and c['base_e_s']==e)
        digest=hashlib.sha256(struct.pack('<4096q',*vals)).hexdigest()
        check(digest==ref['table_sha256']);check(cap==ref['cap_pow2'])
        tables[e]=dict(n_col=len(set(vals)|{0}),cap=cap,sha256=digest)
    per_context={}
    for T in (128,512):
        per_context[T]={cap:record(T,cap) for cap in (0,32,64,128,256,512)}
        for e in range(5):
            cap=tables[e]['cap']; r=per_context[T][cap]
            ref=next(x for x in oldcost['full_precision_rows'] if x['geometry']=='Llama-3-8B T%d'%T and x['base_e_s']==e)
            for k,rk in [('committed','DD_committed'),('u8','DD_u8'),('element_terms','DD_element_terms')]:check(r['totals'][k]==ref[rk])
        # Known independently retained native receipt delta: R9 DD - nonDD.
        a,b=make_layout(T,0,False),make_layout(T,32,False)
        if T==128:check(wire_parts(b)['total']-wire_parts(a)['total']==235008)
    census=json.loads((HERE/'prior/source/r9__r9_ncol.json').read_text())
    b7=next(e for e in census['exports'] if Path(e['export']).name=='llama3_8b_pg_rot1_b7voc0_T128')
    check(len(b7['e_s_per_layer'])==32)
    schedules={'existing_b7_sensitivity':b7['e_s_per_layer'],
               'balanced_synthetic':[2,3,4,4]*8,
               'broad_synthetic':[0,1,2,3,4,4,3,2]*4,
               'uniform_synthetic':[2]*32}
    results=[]
    for name,es in schedules.items():
        for T in (128,512):
            arms={mode:aggregate(es,T,mode) for mode in ['direct','uniform','layer','hybrid']}
            d=arms['direct']['totals']['committed']
            for arm in arms.values():
                arm['committed_pct_vs_direct']=100*(arm['totals']['committed']/d-1)
                arm['wire_delta_vs_direct']=arm['wire']['total']-arms['direct']['wire']['total']
            check(arms['hybrid']['totals']['committed']<=arms['direct']['totals']['committed'])
            check(arms['layer']['totals']['committed']<=arms['uniform']['totals']['committed'])
            check(arms['layer']['lifetime']['exact_stream_peak']==arms['uniform']['lifetime']['exact_stream_peak'])
            results.append(dict(name=name,context=T,e_s_histogram=dict(collections.Counter(es)),arms=arms,
                                scope='Synthetic HIGH/S12 schedule; existing b7 exponents are sensitivity only, no fidelity/proof/profile admission'))
    # Toy arithmetic differential: synthetic rows and fresh public dictionaries.
    row_cases=0
    for es in range(5):
        vals=exp_table(es); col=sorted(set(vals)|{0}); col += [0]*(public_cap(vals)-len(col))
        for T in (32,128,512):
            for _ in range(8):
                xs=[vals[0]]+[0 if j%7==0 else vals[rng.randrange(4096)] for j in range(1,T)]
                total=sum(xs); dic={v:(v*4096//total, v*4096%total) for v in col}
                for v in xs:
                    q,rr=divmod(v<<12,total);check(dic[v]==(q,rr));check(0<=rr<total)
                row_cases+=1
    controls=[]
    def negative(name,ok):check(ok);controls.append(name)
    negative('cap32_not_admitted',any(t['n_col']>32 for t in tables.values()))
    negative('rounding_cap_down',any((t['cap']//2)<t['n_col'] for t in tables.values()))
    # A private row visits only e=0,512: it cannot determine the public cap.
    negative('private_observed_cardinality',public_cap([0,512])<tables[2]['cap'])
    es=schedules['existing_b7_sensitivity']; caps=[tables[e]['cap'] for e in es]; hashes=[tables[e]['sha256'] for e in es]
    digest=schedule_digest(es,caps,hashes)
    badcaps=list(caps);badcaps[-1]=0
    negative('mode_cap_swap_changes_binding',digest!=schedule_digest(es,badcaps,hashes))
    badhash=list(hashes);badhash[0]='0'*64
    negative('table_swap_changes_binding',digest!=schedule_digest(es,caps,badhash))
    for T in (128,512):
        r=per_context[T][256]; b=per_context[T][64]
        negative('cap_rounds_not_free_T%d'%T,r['wire']['main_rounds']-b['wire']['main_rounds']==2)
        negative('cap_does_not_remove_masks_T%d'%T,r['totals']['a_mask_words']+r['totals']['h_mask_words']==b['totals']['a_mask_words']+b['totals']['h_mask_words'])
    negative('cumulative_is_not_peak',results[0]['arms']['layer']['lifetime']['retained_all_layers']>results[0]['arms']['layer']['lifetime']['exact_stream_peak'])
    out=dict(status='PASS',seed=SEED,checks=checks,synthetic_rows=row_cases,negative_controls=controls,
             tables=tables,per_context=per_context,schedules=results,
             existing_public_fixture=dict(name=b7['export'],profile_sha256=b7['profile_sha256'],e_s=es),
             elapsed_s=time.perf_counter()-start,maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
             scope='Arithmetic/layout/wire/payload counts only; zero native proofs or GPU jobs',
             limits=dict(threads=1,CPU_s=59,alarm_s=59,parent_wall_s=60,address_space_MiB=512,estimate_MiB=64))
    (HERE/'result.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps({k:v for k,v in out.items() if k not in ['tables','per_context','schedules','existing_public_fixture']}))

if __name__=='__main__':run()
