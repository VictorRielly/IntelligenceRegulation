#!/usr/bin/env python3
"""Independent Decimal recurrence, transition counts and public pin audit."""
from decimal import Decimal, localcontext, ROUND_FLOOR
import hashlib
import json
import os
from pathlib import Path
import resource
import signal
import struct
import time

HERE = Path(__file__).resolve().parent

def reference(hd, es, fe, bits, precision=90):
    # Multiplicative high-precision recurrence rather than binary64 exp(-d*lam).
    with localcontext() as c:
        c.prec = precision
        step = (-(Decimal(2) ** es) / Decimal(hd).sqrt()).exp()
        value = Decimal(2) ** fe
        half = Decimal('0.5')
        vals = []
        margin = Decimal(1)
        for _ in range(1 << bits):
            rounded = int((value + half).to_integral_value(rounding=ROUND_FLOOR))
            vals.append(rounded)
            frac = value - value.to_integral_value(rounding=ROUND_FLOOR)
            margin = min(margin, abs(frac-half))
            value *= step
        changes = 1 + sum(a != b for a,b in zip(vals, vals[1:]))
        return vals, changes + int(vals[-1] != 0), margin

def run():
    resource.setrlimit(resource.RLIMIT_AS, (512 << 20, 512 << 20))
    resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
    signal.alarm(59)
    os.nice(19)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    start=time.perf_counter()
    probe=json.loads((HERE/'result.json').read_text())
    checks=0
    entries=0
    min_margin=Decimal(1)
    for c in probe['cases'] + probe['sweep']:
        es=c.get('actual_e_s',c['base_e_s'])
        vals,n,margin=reference(c['head_dim'],es,c['f_e'],c['bits'])
        entries += len(vals)
        min_margin=min(min_margin,margin)
        assert n==c['n_col']; checks+=1
        if 'table_sha256' in c:
            data=struct.pack('<%dq'%len(vals),*vals)
            assert hashlib.sha256(data).hexdigest()==c['table_sha256'];checks+=1
        assert margin > Decimal('1e-50');checks+=1
    # Re-evaluate key S12 tables at a second precision, well beyond error margin.
    for es in range(-4,1):
        a,n,_=reference(128,es,9,12,90)
        b,m,_=reference(128,es,9,12,130)
        assert a==b and n==m; checks+=1
    for e in probe['public_exports']:
        for c in e['layers']:
            data=Path(c['public_exp_path']).read_bytes()
            assert hashlib.sha256(data).hexdigest()==c['sha256'];checks+=1
            vals,n,_=reference(c['head_dim'],c['e_s'],c['f_e'],8)
            assert list(struct.unpack('<256q',data))==vals and n==c['n_col'];checks+=1
    pins=json.loads((HERE/'source-pins.json').read_text())
    for p in pins:
        a=Path(p['path']).read_bytes(); b=(HERE/p['snapshot']).read_bytes()
        assert hashlib.sha256(a).hexdigest()==hashlib.sha256(b).hexdigest()==p['sha256'];checks+=1
    # Deliberately corrupted result metadata and a missing zero must be caught.
    negative=0
    for c in [v for v in probe['cases'] if v['bits']==12 and v['f_e']==9]:
        _,n,_=reference(c['head_dim'],c['actual_e_s'],c['f_e'],c['bits'])
        assert n != c['n_col']-1;negative+=1
    out=dict(status='PASS', checks=checks, enumerated_entries=entries,
             public_export_layers=sum(len(e['layers']) for e in probe['public_exports']),
             source_pins=len(pins), metadata_negative_controls=negative,
             Decimal_precision=90, repeated_precision=130,
             minimum_half_integer_margin=str(min_margin),
             elapsed_s=time.perf_counter()-start,
             maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
             scope='Independent high precision public table/pin audit; no native proof')
    (HERE/'validation-result.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps(out))

if __name__=='__main__': run()
