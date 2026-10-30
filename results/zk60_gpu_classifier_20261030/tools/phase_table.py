#!/usr/bin/env python3
"""GPU classifier lane: aggregate one classifier CLI log (HL_PB_TIMING=1, lane binary gcl1) into a phase table.

Reads: PB-TIMING <side> rows (one table per block; per-phase seconds), PB-SLOTSTEP rows (slot sub-steps),
PB-CLI <side> rows (CLI-level phases) and the CLI's segment / proved / classified events.
Writes a JSON summary and prints a markdown table grouped for the GPU port ranking.
usage: phase_table.py LOG SIDE(prove|verify) OUT.json [GUARD.json]"""
import collections, json, re, sys

log, side, out = sys.argv[1], sys.argv[2], sys.argv[3]
guard = json.load(open(sys.argv[4])) if len(sys.argv) > 4 else None
phases = collections.OrderedDict()       # name -> [secs, count, half]
slotsteps = collections.OrderedDict()    # (slot, label) -> [secs, count], blocks only
stagesteps = collections.OrderedDict()   # (stage, slot, label) -> [secs, count], stages IN-C / OUT-C
nseg = 0                                 # segment events seen: 0 = stage IN-C running, 1..L = block k, L+1 = OUT-C
cli = collections.OrderedDict()
blocks = 0
block_walls = []
events = []
row = re.compile(r'^PB-TIMING ' + side + r' \| (.+?)\s*\| (.+?)\s*\|\s*([0-9.]+) \|')
head = re.compile(r'^PB-TIMING ' + side + r' \[.*\] (\d+) phases, wall ([0-9.]+) s')
step = re.compile(r'^PB-SLOTSTEP slot (\d+) \| (.+?)\s*\|\s*([0-9.]+) s \|')
clir = re.compile(r'^PB-CLI ' + side + r' \| (.+?) \| ([0-9.]+) s$')
gpur = re.compile(r'^PB-CLI ' + side + r' \| gpu \| (.*)$')
gpu_line = None
blocks_total = 0
for line in open(log, errors='replace'):
    line = line.rstrip('\n')
    m = head.match(line)
    if m:
        blocks += 1
        block_walls.append(float(m.group(2)))
        continue
    m = row.match(line)
    if m:
        name, half, secs = m.group(1).strip(), m.group(2).strip(), float(m.group(3))
        if name in ('SUM OF PHASES', 'WALL CLOCK OF THE CALL', 'unaccounted (wall - sum)'):
            continue
        p = phases.setdefault(name, [0.0, 0, half])
        p[0] += secs; p[1] += 1
        continue
    m = step.match(line)
    if m:
        if nseg == 0 or (blocks_total and nseg > blocks_total):
            k = ('IN-C' if nseg == 0 else 'OUT-C', int(m.group(1)), m.group(2).strip())
            st = stagesteps.setdefault(k, [0.0, 0])
        else:
            k = (int(m.group(1)), m.group(2).strip())
            st = slotsteps.setdefault(k, [0.0, 0])
        st[0] += float(m.group(3)); st[1] += 1
        continue
    m = gpur.match(line)
    if m:
        gpu_line = m.group(1)
        continue
    m = clir.match(line)
    if m:
        cli[m.group(1)] = cli.get(m.group(1), 0.0) + float(m.group(2))
        continue
    if line.startswith('{"event"'):
        try:
            ev = json.loads(line)
            events.append(ev)
            if ev.get('event') == 'segment':
                nseg += 1
            if ev.get('event') == 'loaded':
                blocks_total = int(ev.get('blocks', 0))
        except ValueError:
            pass

def group(name, half):
    n = name
    if n.startswith('slot '):
        s = int(n.split()[1])
        if s in (14, 15, 16, 17, 18):
            return f'zero-check slot {s:02d}'
        if s in (5, 6, 7, 8, 9, 10, 11, 12, 13):
            return 'matmul slots 05-13 (weight folds + sumchecks)'
        if s in (0, 1, 2, 3):
            return 'norm slots 00-03'
        if s in (19, 20):
            return 'lookup-table slots 19-20'
        if s in (21, 22):
            return 'endpoint slots 21-22'
        return f'other slot {s:02d} ({half})'
    if n.startswith('run: witness'):
        return 'witness (CPU builder)'
    if n.startswith('run: block load'):
        return 'block load + statement check'
    if n.startswith('run: boundary B_k'):
        return 'boundary B_k commit'
    if 'boundary B_(k-1) opening' in n:
        return 'boundary opening / verify'
    if n.startswith('A: commit') or n.startswith('H: commit') or n.startswith('M: mask commit'):
        return 'commit A + H + M (encode + Merkle)'
    if n.startswith('H: ') and 'inverse' in n or n.startswith('H: dictionary') or n.startswith('H: the three table'):
        return 'LogUp helper inverses (H)'
    if n.startswith('A: allocate'):
        return 'A planes -> committed rows (conversion)'
    if n.startswith('A: ') or n.startswith('H: '):
        return 'A/H lookups, histograms, mask + zero-sum rows'
    if n.startswith('open ') or n.startswith('verify M') or n.startswith('verify A') or n.startswith('verify H') or n.startswith('verify endpoint'):
        return 'openings (prover) / PCS verify (verifier)'
    if n.startswith('frame') or n.startswith('sink'):
        return 'frame encode/decode + disk'
    if n.startswith('setup') or n.startswith('transcript'):
        return 'setup + transcript'
    return f'other ({half}): {n}'

groups = collections.OrderedDict()
for name, (secs, cnt, half) in phases.items():
    g = group(name, half)
    groups[g] = groups.get(g, 0.0) + secs
tot_blocks = sum(block_walls)
res = {
    'log': log, 'side': side, 'blocks': blocks, 'sum_block_walls_s': tot_blocks,
    'phases': {k: {'seconds': v[0], 'count': v[1], 'half': v[2]} for k, v in phases.items()},
    'groups': dict(sorted(groups.items(), key=lambda kv: -kv[1])),
    'slotsteps': {f'{k[0]:02d} {k[1]}': {'seconds': v[0], 'count': v[1]} for k, v in slotsteps.items()},
    'stagesteps': {f'{k[0]} {k[1]:02d} {k[2]}': {'seconds': v[0], 'count': v[1]} for k, v in stagesteps.items()},
    'cli': cli, 'gpu': gpu_line,
    'events': [e for e in events if e.get('event') in ('loaded', 'proved', 'classified', 'refused')],
    'segments': [(e.get('index'), e.get('bytes'), e.get('elapsed_seconds')) for e in events if e.get('event') == 'segment'],
}
if guard:
    res['guard'] = {k: guard.get(k) for k in ('exit', 'child_wall_seconds', 'peak_rss_gib', 'peak_cgroup_gib', 'peak_vram_mib', 'enforcement', 'min_mem_available_gib')}
json.dump(res, open(out, 'w'), indent=1)
print(f'## {side}: {blocks} blocks, sum of block walls {tot_blocks:.1f} s')
if guard:
    print(f"guard: exit {guard.get('exit')}, child wall {guard.get('child_wall_seconds'):.1f} s, peak RSS {guard.get('peak_rss_gib')} GiB, cgroup {guard.get('peak_cgroup_gib')} GiB, VRAM {guard.get('peak_vram_mib')} MiB")
print(f'\n| group | seconds ({blocks} blocks) | % of block walls |\n|---|---:|---:|')
for g, s in sorted(groups.items(), key=lambda kv: -kv[1]):
    print(f'| {g} | {s:.2f} | {100 * s / tot_blocks if tot_blocks else 0:.1f}% |')
print('\n| CLI phase | seconds |\n|---|---:|')
for k, v in cli.items():
    print(f'| {k} | {v:.2f} |')
if slotsteps:
    print('\n| slot sub-step | seconds | count |\n|---|---:|---:|')
    for k, v in slotsteps.items():
        print(f'| {k[0]:02d} {k[1]} | {v[0]:.2f} | {v[1]} |')
if stagesteps:
    print('\n| stage slot sub-step | seconds | count |\n|---|---:|---:|')
    for k, v in stagesteps.items():
        print(f'| {k[0]} {k[1]:02d} {k[2]} | {v[0]:.2f} | {v[1]} |')
if gpu_line:
    print('\ngpu:', gpu_line)
