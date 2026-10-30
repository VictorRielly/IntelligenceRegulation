from pathlib import Path
import hashlib,json,platform,os
E=Path(__file__).resolve().parent;R=E.parents[1];P=R.parents[1]
prior=R/'experiments/sc-szc-clause-census-20261004'
pins=[]
for name in ['field_support.py','source_port.py','polynomial_ir.py','oracle.py']:
    b=(prior/name).read_bytes();(E/name).write_bytes(b)
    pins.append(dict(origin=str(prior/name),copy=name,sha256=hashlib.sha256(b).hexdigest(),bytes=len(b)))
(E/'local-reference-provenance.json').write_text(json.dumps(pins,indent=2)+'\n')
native=E/'native';native.mkdir(exist_ok=True)
paths=['ops/zkp-mvp/trained-1b/zkp-core/src/sumcheck/grouped.rs',
 'ops/zkp-mvp/trained-1b/zkp-core/src/sumcheck/rounds.rs',
 'ops/zkp-mvp/trained-1b/hashline/src/private_block/argument.rs',
 'ops/zkp-mvp/trained-1b/hashline/src/private_block/pad.rs',
 'ops/zkp-mvp/trained-1b/hashline/src/private_block/layout.rs',
 'ops/zkp-mvp/trained-1b/zkp-core/src/field.rs',
 'results/zk60_1b_native_20261017/r14/final-working-tree/zkp-core/src/sumcheck/grouped.rs',
 'results/zk60_1b_native_20261017/r14/final-working-tree/hashline/src/private_block/argument.rs',
 'results/zk60_1b_native_20261017/r14/CURRENT_DEV_STATE.json',
 'results/zk60_1b_native_20261017/r14/MATCHED_R13_R14_COMPARISON.json']
pins=[]
for i,name in enumerate(paths):
    b=(P/name).read_bytes();dest=f'native/{i:02}-{Path(name).name}'
    (E/dest).write_bytes(b);pins.append(dict(path=str(P/name),snapshot=dest,sha256=hashlib.sha256(b).hexdigest(),bytes=len(b)))
(E/'native-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
a=(E/'native/02-argument.rs').read_text();b=(E/'native/07-argument.rs').read_text()
def grouped(s):
    i=s.index('SC_SZC => {');j=s.index('SC_TAB => {',i);v=s[i:j]
    return v[v.index('let groups = vec!['):v.index('let poly_bracket = bracket.clone();')]
assert grouped(a)==grouped(b)
(E/'source-facts.json').write_text(json.dumps(dict(grouped_bracket_body_identical_between_active_and_r14=True,
 grouped_bracket_body_sha256=hashlib.sha256(grouped(a).encode()).hexdigest(),
 source_scope='Literal private SC_SZC groups/bracket and host table loops; not whole-program incidence or security review',
 facts=['Only SC_SZC assigns def.groups in inspected argument.rs',
 'All k columns receive cur/dif and max_degree interpolation in GroupedEqRounds::round',
 'Three Eq columns precede mask/data/helper/support tables',
 'Bracket group0 uses every remaining column in the selected ls2/3 lp2 projection',
 'Host groups use sum/ght and s8/rsl/gs, subsets of group0 dependencies',
 'All original tables fold and all finals preserve original order']),indent=2)+'\n')
(E/'hardware.json').write_text(json.dumps(dict(platform=platform.platform(),python=platform.python_version(),cpu=next((l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),None),allowed_affinity=sorted(os.sched_getaffinity(0)),gpu_used=False,threads=1,estimated_memory_mib=64),indent=2)+'\n')
print('Pinned',len(pins),'native source/public report files; references copied with provenance.')
