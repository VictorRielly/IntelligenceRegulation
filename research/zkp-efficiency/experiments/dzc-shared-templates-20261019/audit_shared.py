"""Independent exact-address and initialization replay of shared templates."""
import collections, copy, hashlib, json, os, re, resource, signal, time
from pathlib import Path
import audit

H = Path(__file__).resolve().parent


def replay(q, p):
    ns = q['ops']; slots = {int(k): v for k, v in p['slots'].items()}
    memory = {}; checks = 0
    for g in p['groups']:
        cls = p['templates'][g['template']]; shape = cls['shape']; addresses = iter(g['map'])
        assert g['index'] in cls['instances']
        assert shape['inputs'] == len(g['inputs'])
        local = []
        for d in g['inputs']:
            addr = next(addresses); assert 0 <= addr < p['capacity']
            assert memory.get(addr) == d, ('stale/uninitialized', g['index'], d, addr)
            local.append(d); checks += 1
        for j, x in enumerate(shape['ops']):
            orig = ns[g['start'] + j]
            assert x['kind'] == orig['kind']
            assert [local[d] for d in x['deps']] == orig['deps']
            if x['kind'].startswith('load_'):
                addr = next(addresses)
                limit = {'load_raw':118, 'load_param':129, 'load_base':36}[x['kind']]
                assert 0 <= addr < limit
                assert addr == orig['slot'], ('wrong source address',g['index'],j,addr,orig['slot'])
            local.append(orig['id']); checks += 1
        for d in shape['outputs']:
            addr = next(addresses); assert 0 <= addr < p['capacity']
            memory[addr] = local[d]; checks += 1
        assert next(addresses, None) is None
        # Independently derive what must survive this boundary from future uses.
        b = g['end']
        future = {d for x in ns[b:] for d in x['deps'] if d < b}
        future |= {d for d in q['output'] if d < b}
        assert all(memory.get(slots[d]) == d for d in future)
        assert len({slots[d] for d in future}) == len(future)
        checks += 1
    assert [memory[slots[d]] for d in q['output']] == q['output']
    return checks


def main():
    start=time.perf_counter(); os.nice(19)
    cpu=min(os.sched_getaffinity(0)); os.sched_setaffinity(0,{cpu})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59)); signal.alarm(59)
    q=json.loads((H/'scalar-dags.json').read_text())
    p=json.loads((H/'group-plan.json').read_text()); assert q['baseline']==q['driven']
    checks=replay(q['driven'],p); controls={}
    repeated=[g for g in p['groups'] if len(p['templates'][g['template']]['instances'])>1]
    for kind in ['load_address','input_address','output_address','instance_map','out_of_bounds','dependency']:
        bad=copy.deepcopy(p); g=bad['groups'][repeated[1]['index']]
        shape=bad['templates'][g['template']]['shape']; nin=shape['inputs']
        if kind=='load_address':g['map'][nin]=(g['map'][nin]+1)%118
        elif kind=='input_address':g['map'][0]=(g['map'][0]+1)%p['capacity']
        elif kind=='output_address':g['map'][-1]=(g['map'][-1]+1)%p['capacity']
        elif kind=='instance_map':g['map']=bad['groups'][repeated[0]['index']]['map'][:]
        elif kind=='out_of_bounds':g['map'][nin]=65535
        else:
            op=next(x for x in shape['ops'] if x['deps'])
            op['deps'][0]=(op['deps'][0]+1)%shape['inputs']
        try:replay(q['driven'],bad)
        except (AssertionError,IndexError):controls[kind]=True
        else:raise AssertionError(('undetected',kind))
    audit.H=H; asm=audit.assembly()
    tn=[n for n in asm if re.search(r'template_\d+$',n)]
    un=[n for n in asm if re.search(r'helper_\d+$',n)]
    assert len(tn)==len(p['templates'])==10 and len(un)==19
    assert asm['baseline']['call_count']==884
    assert asm['driven']['call_count']==asm['unique']['call_count']==19
    assert all(asm[n]['call_count']==0 for n in tn+un)
    def size(root):
        used=set()
        def visit(n):
            if n in used:return
            used.add(n)
            for c in asm[n]['calls']:visit(c)
        visit(root)
        return dict(code_bytes=sum(asm[n]['symbol_bytes'] for n in used),
                    instructions=sum(asm[n]['instruction_lines'] for n in used),
                    functions=len(used),entry=asm[root])
    sizes={n:size(n) for n in ['baseline','unique','driven']}
    # Parse every emitted immutable map rather than trusting emitter counts.
    src=(H/'kernels.rs').read_text(); emitted={int(k):[int(x) for x in a.split(',')]
        for k, a in re.findall(r'static MAP_(\d+):\[u16;\d+\]=\[([\d,]+)\];',src)}
    assert set(emitted)=={g['index'] for g in repeated}
    assert all(emitted[g['index']]==g['map'] for g in repeated)
    entries=sum(len(v) for v in emitted.values()); assert entries==p['map_entries_per_row']
    assert 2*entries==p['map_bytes']
    requested=4320+16*(p['crossing_loads']+p['crossing_stores']+5)
    for pin in json.loads((H/'source-pins.json').read_text()):
        assert hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'];checks+=1
    field=Path('/home/victor/IntelligenceRegulation/ops/zkp-mvp/gpu-zerocheck/zkp-core/src/field.rs')
    assert field.read_bytes()==(H/'native-field.rs').read_bytes()
    res=json.loads((H/'result.json').read_text()); assert res['status']=='PASS' and all(res['controls'].values())
    out=dict(status='PASS',checks=checks,controls=controls,templates=len(tn),calls=19,
             assembly=sizes,scratch_bytes=16*p['capacity'],map_storage_bytes=2*entries,
             logical_map_bytes_requested_per_row=2*entries,
             scalar_logical_bytes=4320,unique_logical_bytes=requested,
             shared_logical_bytes=requested+2*entries,physical_DRAM_bytes=None,
             original_fold_reads=118,original_fold_writes=59,
             original_fold_field_ops=dict(add=59,sub=59,mul=59),
             wall_seconds=time.perf_counter()-start,
             rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
             threads=1,cpu_affinity=[cpu],limits='59s CPU/wall;512MiBAS;one nice19 CPU',
             scope='Symbolic template lineage,public address maps,initialized crossing slots,compiled call graph/ELF sizes and source pins. Static stack extent and logical requested bytes are not physical traffic/GPU registers or proof time.')
    (H/'audit-shared-result.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps({k:v for k,v in out.items() if k!='assembly'},indent=2))
    for n,v in sizes.items():print(n,{**{k:v[k] for k in ['code_bytes','instructions','functions']},**{k:a for k,a in v['entry'].items() if k!='calls'}})

if __name__=='__main__':main()
