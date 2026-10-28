"""Capacity-only model of the pinned pool policy. Never allocates tensor data.

This is authored Python, not executed Rust/CUDA. Byte capacity and release
completion are explicit modeled quantities, never GPU/RSS measurements.
"""
import hashlib, json, os, pathlib, platform, random, resource, time

HERE = pathlib.Path(__file__).resolve().parent
SEED = 2026102092


class Pool:
    def __init__(self, budget=1 << 60, deferred=False):
        self.budget, self.deferred = budget, deferred
        self.allocs, self.active, self.idle, self.pending = {}, {}, [], []
        self.next_id = 1
        self.cap, self.fail, self.reuse = 0, None, True
        self.stats = dict(fresh_count=0, fresh_bytes=0, reuse_count=0,
                          reuse_capacity_bytes=0, reuse_requested_bytes=0,
                          raw_count=0, raw_bytes=0)
        self.peak = 0

    def snapshot(self):
        lp = sum(self.allocs[a]['bytes'] for a in self.active.values() if self.allocs[a]['kind'] == 'pool')
        raw = sum(self.allocs[a]['bytes'] for a in self.active.values() if self.allocs[a]['kind'] == 'raw')
        idle = sum(self.allocs[a]['bytes'] for a in self.idle)
        pending = sum(self.allocs[a]['bytes'] for a in self.pending)
        physical = sum(a['bytes'] for a in self.allocs.values())
        self.peak = max(self.peak, physical)
        return dict(live_pooled_bytes=lp, live_raw_bytes=raw, idle_pooled_bytes=idle,
                    pending_release_bytes=pending, physical_bytes=physical,
                    peak_physical_bytes=self.peak, idle_count=len(self.idle),
                    live_requested_bytes=sum(self.allocs[a]['requested'] for a in self.active.values()),
                    stats=self.stats.copy())

    def step(self, command):
        op = command['op']
        effects, status, selected = [], 'ok', None
        if op in ('take', 'raw'):
            name, request = command['name'], command['bytes']
            assert name not in self.active and request > 0
            assert op == 'raw' or request % 8 == 0
            matches = []
            if op == 'take' and self.reuse:
                matches = [i for i, a in enumerate(self.idle)
                           if self.allocs[a]['bytes'] == request or
                           (command['mode'] == 'min' and self.allocs[a]['bytes'] >= request)]
            if matches:
                # Stable first minimum, matching iter/enumerate + strict '<'.
                i = min(matches, key=lambda j: self.allocs[self.idle[j]]['bytes'])
                selected = self.idle[i]
                self.idle[i] = self.idle[-1]
                self.idle.pop()
                self.allocs[selected]['requested'] = request
                self.active[name] = selected
                self.stats['reuse_count'] += 1
                self.stats['reuse_capacity_bytes'] += self.allocs[selected]['bytes']
                self.stats['reuse_requested_bytes'] += request
                effects.append(dict(kind='reuse', id=selected, name=name, requested=request))
            else:
                if op == 'take' and self.cap and request > self.cap:
                    status = 'cap'
                else:
                    if op == 'take':
                        seen = self.stats['fresh_count']
                        self.stats['fresh_count'] += 1
                        if seen == self.fail:
                            self.fail = None
                            status = 'injected'
                    if status == 'ok' and sum(a['bytes'] for a in self.allocs.values()) + request > self.budget:
                        status = 'oom'
                    if status == 'ok':
                        selected = self.next_id
                        self.next_id += 1
                        self.allocs[selected] = dict(bytes=request, requested=request, kind='pool' if op == 'take' else 'raw')
                        self.active[name] = selected
                        if op == 'take':
                            self.stats['fresh_bytes'] += request
                        elif command.get('counted', True):
                            self.stats['raw_count'] += 1
                            self.stats['raw_bytes'] += request
                        effects.append(dict(kind='allocate', id=selected, name=name, bytes=request, allocation_kind=self.allocs[selected]['kind']))
        elif op == 'drop':
            a = self.active.pop(command['name'])
            if self.allocs[a]['kind'] == 'pool' and len(self.idle) < 64:
                self.idle.append(a)
                effects.append(dict(kind='cache', id=a))
            else:
                self.release(a, effects)
        elif op == 'drain':
            ids, self.idle = self.idle, []
            for a in ids:
                self.release(a, effects)
            if command.get('sync', False):
                self.sync(effects)
        elif op == 'sync':
            self.sync(effects)
        elif op == 'arm':
            self.stats['fresh_count'] = 0
            self.fail = command['n']
        elif op == 'cap':
            self.cap = command['bytes']
        elif op == 'reuse':
            self.reuse = command['enabled']
        elif op == 'reset':
            self.stats = {k: 0 for k in self.stats}
        else:
            assert op == 'snapshot'
        return dict(command=command, status=status, selected=selected, effects=effects, snapshot=self.snapshot())

    def release(self, a, effects):
        if self.deferred:
            self.pending.append(a)
            effects.append(dict(kind='pending', id=a))
        else:
            del self.allocs[a]
            effects.append(dict(kind='free', id=a))

    def sync(self, effects):
        for a in self.pending:
            del self.allocs[a]
            effects.append(dict(kind='free', id=a))
        self.pending.clear()


def extract(s, name):
    import re
    m = re.search(r'(?:pub(?:\([^)]*\))? )?fn ' + name + r'\(', s)
    assert m, name
    start = m.start()
    pos = s.index('{', start)
    depth, end = 1, pos + 1
    # These pinned functions contain balanced braces in string/comment text.
    while depth:
        depth += (s[end] == '{') - (s[end] == '}')
        end += 1
    return s[start:end], s[:start].count('\n') + 1


def source_facts():
    paths = list((HERE / 'startup').glob('*cuda.rs'))
    names = ['pool_take','pool_take_min','pool_put','fresh_alloc_gate','note_reuse','dev_pool_drain','dev_reserve_hard','commit_zk_chunked','chunk_plan']
    facts = []
    for p in paths:
        s = p.read_text()
        functions = {}
        for n in names:
            body, line = extract(s, n)
            functions[n] = dict(sha256=hashlib.sha256(body.encode()).hexdigest(), line=line)
            (HERE / ('source-' + p.name.split('__')[0] + '-' + n + '.rs.txt')).write_text(body + '\n')
        facts.append(dict(path=p.name, sha256=hashlib.sha256(s.encode()).hexdigest(), functions=functions))
    for name in names[:7]:
        assert len({r['functions'][name]['sha256'] for r in facts}) == 1, name
    frozen = next(p for p in paths if p.name.startswith('results__'))
    s = frozen.read_text()
    body = extract(s, 'commit_zk_chunked')[0]
    required = ['rmax * n','rmax * pw','rmax * nn','B3_STATE_SLOTS * nn','(state_words + 1) / 2','dev.alloc::<u32>(nn * 8)','key_words(k)','key: Option<&[u8; 32]>']
    assert all(x in body for x in required)
    assert 'const B3_STATE_SLOTS: usize = 8 * 24 + 1;' in s
    assert 'fn key_words(key: &[u8; 32]) -> [u32; 8]' in s
    assert 'pool.len() < 64' in extract(s, 'pool_put')[0]
    (HERE/'source-facts.json').write_text(json.dumps(dict(files=facts, common_pool_policy=True,
        frozen_chunked_request_tokens=required, key_upload_bytes=32,
        uncounted_key_scope='keyed chunked commitment only; key upload has no note_raw_alloc in this body',
        existing_drains=True, comment_warning='historical zk.rs failure comments explicitly called hypotheses'),indent=2)+'\n')


def run():
    t0 = time.perf_counter()
    source_facts()
    cases = []
    def case(name, commands, budget=1 << 60, deferred=False, metadata=None):
        p = Pool(budget, deferred)
        events = [p.step(c) for c in commands]
        cases.append(dict(name=name,budget=budget,deferred=deferred,metadata=metadata,events=events))
        return cases[-1]
    def take(name, b, mode='exact'):
        return dict(op='take',name=name,bytes=b,mode=mode)
    def drop(name):
        return dict(op='drop',name=name)
    case('best-fit-tail-and-ties', [take('a',1024),take('b',512),take('c',512),drop('a'),drop('b'),drop('c'),take('d',8,'min'),take('e',8,'min'),take('f',8,'min')])
    case('count-cap-is-not-byte-cap', [take(str(i),8*(2**25+i)) for i in range(65)] + [drop(str(i)) for i in range(65)])
    case('one-shot-reuse-raw-cap', [take('a',128),drop('a'),dict(op='arm',n=0),take('b',128),dict(op='raw',name='raw',bytes=32),take('c',64),take('d',64),dict(op='cap',bytes=8),take('e',16),dict(op='cap',bytes=0),drop('b'),dict(op='reuse',enabled=False),take('f',128)])
    case('volume-versus-peak', [take('x',1024),drop('x'),dict(op='drain',sync=True)]*40)
    # Two explicit release-completion brackets, not an assumption about CUDA.
    commands = [take('live',256),take('idle',512),drop('idle'),dict(op='drain',sync=False),dict(op='raw',name='try',bytes=512),dict(op='sync'),dict(op='raw',name='after',bytes=512)]
    case('deferred-free-needs-sync',commands,budget=768,deferred=True)
    case('immediate-free-bracket',commands,budget=1280,deferred=False)
    case('returned-resident-capacity', [take('data',4096),dict(op='raw',name='pads',bytes=512),
        dict(op='arm',n=1),take('resident_coef',4096),take('resident_coef2',8192),
        drop('resident_coef'),take('chunk_coef',256,'min'),take('chunk_coef2',512,'min'),
        take('chunk_enc',1024,'min'),take('chunk_state',256,'min')])
    # Constructed partial-commit schedules use the actual public allocation
    # formulas. They are not complete layer traces or admitted model profiles.
    geometries = [(1,32,8,4),(127,1024,64,4),(128,1024,64,4),(129,1024,64,4),
                  (257,4096,64,4),(3033,16384,64,4),(3028,16384,64,4)]
    for rows,n,q,rate in geometries:
        for compact in (False,True):
            for drains in (False,True):
                commands=[]
                nn=n*rate; rmax=min(rows,128); pw=n+q if compact else nn
                for it in range(4):
                    if drains: commands.append(dict(op='drain',sync=True))
                    prefix=f'p{it}'
                    commands += [take(prefix+'data',rows*n*8),dict(op='raw',name=prefix+'pads',bytes=rows*q*8),dict(op='raw',name=prefix+'powers',bytes=nn*8)]
                    commands += [take(prefix+k,b,'min') for k,b in [('coef',rmax*n*8),('coef2',rmax*pw*8),('enc',rmax*nn*8),('state',((193*nn+1)//2)*8)]]
                    commands += [dict(op='raw',name=prefix+'leaves',bytes=nn*32),dict(op='raw',name=prefix+'key',bytes=32,counted=False)]
                    commands += [drop(prefix+k) for k in ['key','leaves','state','enc','coef2','coef','data','pads','powers']]
                case(f'chunked-{rows}-{n}-compact{int(compact)}-drain{int(drains)}',commands,
                     metadata=dict(rows=rows,n=n,q=q,nn=nn,rmax=rmax,pw=pw,commit_iterations=4,
                                   compact=compact,drains=drains,keyed=True,scope='constructed commit/drop partial trace; no opening or live prior commitments'))
    # Shape churn changes only synthetic public row counts. This contrasts
    # the fixed-geometry negative above; it does not recreate historical logs.
    for drains in (False,True):
        commands=[];n=16384;nn=4*n;q=64;rmax=128
        for it,rows in enumerate([3033,3028,3031,3029]):
            prefix=f'm{it}'
            if drains: commands.append(dict(op='drain',sync=True))
            commands += [take(prefix+'data',rows*n*8),dict(op='raw',name=prefix+'pads',bytes=rows*q*8),dict(op='raw',name=prefix+'powers',bytes=nn*8)]
            commands += [take(prefix+k,b,'min') for k,b in [('coef',rmax*n*8),('coef2',rmax*nn*8),('enc',rmax*nn*8),('state',((193*nn+1)//2)*8)]]
            commands += [dict(op='raw',name=prefix+'leaves',bytes=nn*32),dict(op='raw',name=prefix+'key',bytes=32,counted=False)]
            commands += [drop(prefix+k) for k in ['key','leaves','state','enc','coef2','coef','data','pads','powers']]
        case(f'mixed-rows-drain{int(drains)}',commands,metadata=dict(scope='synthetic row-count churn with source-derived commit formulas',rows=[3033,3028,3031,3029],n=n,nn=nn,q=q,commit_iterations=4,drains=drains))
    # Random legal ownership traffic: lengths are small public test constants.
    rng=random.Random(SEED)
    for trial in range(20):
        p=Pool(budget=4096,deferred=bool(trial%2)); events=[]
        for i in range(100):
            r=rng.randrange(10)
            if r < 5:
                c=dict(op='take',name=f'b{i}',bytes=rng.choice([8,16,24,64,128,256,512,1024]),mode=rng.choice(['exact','min']))
            elif r == 5:
                c=dict(op='raw',name=f'r{i}',bytes=rng.choice([4,32,512]),counted=bool(rng.randrange(2)))
            elif r == 6 and p.active:
                c=drop(rng.choice(list(p.active)))
            elif r == 7:
                c=dict(op='drain',sync=bool(rng.randrange(2)))
            elif r == 8:
                c=dict(op='arm',n=rng.randrange(3))
            else:
                c=dict(op='sync')
            events.append(p.step(c))
        cases.append(dict(name=f'random-{trial}',budget=p.budget,deferred=p.deferred,metadata=None,events=events))
    (HERE/'events.json').write_text(json.dumps(dict(seed=SEED,cases=cases),separators=(',',':'))+'\n')
    output=dict(status='GENERATED',cases=len(cases),events=sum(len(c['events']) for c in cases),seed=SEED,
                wall_seconds=time.perf_counter()-t0,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                threads=len(list(pathlib.Path('/proc/self/task').iterdir())),affinity=sorted(os.sched_getaffinity(0)),
                nice=os.nice(0),python=platform.python_version(),hardware=platform.platform(),
                scope='source-pinned capacity model only; no native/GPU/proof execution',
                cpu_model=next((x.split(':',1)[1].strip() for x in pathlib.Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),None))
    (HERE/'model-result.json').write_text(json.dumps(output,indent=2)+'\n')
    print(json.dumps(output))


if __name__ == '__main__':
    run()
