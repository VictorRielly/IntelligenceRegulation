#!/usr/bin/env python3
"""GPU classifier lane: the WHOLE-PROCESS phase table of one classifier prove (or verify) from phase_table.py's
JSON: CLI phases outside the run, the run's sealing pass and stages, and the 26 blocks split by group; with the
witness counted twice (seal_chain + the run). Optional second JSON (e.g. the GPU run) printed side by side.
usage: whole_table.py PROFILE.json [PROFILE2.json]"""
import json, sys

def rows_prove(j):
    cli = j['cli']; g = j['groups']; seg = j['segments']; child = j['guard']['child_wall_seconds']
    seal = j['cli'].get('run sealing pass (every block loaded once, statement checks)', 0.0)
    t0 = seg[0][2]                  # end of stage IN-C, counted from the run's start (sealing pass included)
    stage_in = t0 - seal
    stage_out = seg[-1][2] - seg[-2][2]
    blocks = j['sum_block_walls_s']
    out = [
        ('process start, args, model digest pass (load_export)', cli.get('args + directories + load_export (the digest pass)', 0.0)),
        ('tied classifier tables re-derived', cli.get('tied classifier tables (re-derived from the pinned checkpoint)', 0.0)),
        ('content, stage IN-C inputs, x_in', cli.get('content, honest stage IN-C inputs, x_in load', 0.0)),
        ('seal_chain: every block loaded + witness built (pass 1) + parity + CS-3', cli.get('seal_chain (every block: load, witness, int16, parity, CS-3)', 0.0)),
        ('stage OUT-C values, input endpoint seal, statement', cli.get('stage OUT-C values, input endpoint seal, statement', 0.0)),
        ('run sealing pass: every block loaded again + statement checks', seal),
        ('stage IN-C prove (vocabulary LogUp, its commitments)', stage_in),
    ]
    for k, v in g.items():
        out.append(('block: ' + k, v))
    out.append(('stage OUT-C prove', stage_out))
    out.append(('owner file, statement, rename', cli.get('owner file, unverified statement, rename', 0.0)))
    acc = sum(v for _, v in out)
    out.append(('process exit, other (guard child wall - sum)', child - acc))
    return out, child, blocks

def rows_verify(j):
    cli = j['cli']; g = j['groups']; child = j['guard']['child_wall_seconds']
    blocks = j['sum_block_walls_s']
    out = [
        ('process start, args, model digest pass (load_export)', cli.get('load_export (the digest pass)', 0.0)),
        ('tied classifier tables re-derived', cli.get('tied classifier tables (re-derived from the pinned checkpoint)', 0.0)),
        ('statement door + reading the 28 segments', cli.get('statement door (re-render, byte compare) + segment reads', 0.0)),
        ('pre-header stage-shape check: every block loaded again', cli.get('pre-header stage-shape check (every block loaded once)', 0.0)),
        ('stage IN-C verify', cli.get('stage IN-C', 0.0)),
    ]
    for k, v in g.items():
        out.append(('block: ' + k, v))
    out.append(('stage OUT-C verify', cli.get('stage OUT-C', 0.0)))
    acc = sum(v for _, v in out)
    out.append(('statement publish, process exit, other (guard child wall - sum)', child - acc))
    return out, child, blocks

def table(path):
    j = json.load(open(path))
    return (rows_prove if j['side'] == 'prove' else rows_verify)(j), j

(a, ja) = table(sys.argv[1])
b = table(sys.argv[2]) if len(sys.argv) > 2 else None
ra, ca, ba = a
print(f"side {ja['side']}: guard child wall {ca:.1f} s, block walls {ba:.1f} s, peak RSS {ja['guard']['peak_rss_gib']} GiB, VRAM {ja['guard']['peak_vram_mib']} MiB")
if b:
    (rb, cb, bb), jb = b
    db = dict(rb)
    print(f"second: guard child wall {cb:.1f} s, block walls {bb:.1f} s, peak RSS {jb['guard']['peak_rss_gib']} GiB, VRAM {jb['guard']['peak_vram_mib']} MiB")
    print('\n| phase | A seconds | A % | B seconds | B % | A / B |\n|---|---:|---:|---:|---:|---:|')
    keys = [k for k, _ in ra] + [k for k, _ in rb if k not in dict(ra)]
    da = dict(ra)
    for k in keys:
        x, y = da.get(k, 0.0), db.get(k, 0.0)
        r = f'{x / y:.1f}x' if y > 0.005 and x > 0.005 else ''
        print(f'| {k} | {x:.2f} | {100 * x / ca:.1f}% | {y:.2f} | {100 * y / cb:.1f}% | {r} |')
    print(f'| **total (guard child wall)** | **{ca:.1f}** | 100% | **{cb:.1f}** | 100% | **{ca / cb:.2f}x** |')
else:
    print('\n| phase | seconds | % of the process |\n|---|---:|---:|')
    for k, v in ra:
        print(f'| {k} | {v:.2f} | {100 * v / ca:.1f}% |')
    print(f'| **total (guard child wall)** | **{ca:.1f}** | 100% |')
