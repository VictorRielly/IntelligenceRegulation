"""Allocation-free current 8B T32 H census, explicitly gross, not a speed model."""
from pathlib import Path
import datetime, hashlib, json, os, platform, re, resource, signal, time

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_CPU,(59,59));resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2));signal.alarm(59)
start=time.perf_counter()
shape=(HERE/'native/shape.rs').read_text();protocol=(HERE/'native/protocol.rs').read_text()
assert 'pub(crate) const LLAMA3_8B_LOG_COLS: usize = 13;' in shape
assert 'Dom::F => 9,' in shape and 'Dom::Q => 13,' in shape and 'Dom::Kv => 12,' in shape
assert 'self.lookups_per_position(dom).div_ceil(2)' in shape
assert 'let u8_inv = u8_denominator_inverses(alpha, g_u8);' in protocol
assert 'let inv = inverses(tv.iter().map(|t| alpha.sub(*t)).collect())?;' in protocol

sizes=dict(L=8192,D=32*4096,Q=32*32*128,Kv=32*8*128,S=32*32*32,F=32*16384)
cols=dict(L=2,D=34,Q=13,Kv=12,S=13,F=9)
rows=[]
for dom,n in sizes.items():
    c=cols[dom];helpers=(c+1)//2
    rows.append(dict(domain=dom,positions=n,lookup_columns=c,U8_queries=n*c,reciprocal_helper_planes=helpers,
        old_U8_H_base_rows=2*helpers*(n//8192),old_U8_H_payload_bytes=16*helpers*n,
        separate_small_table_pushforwards=c,one_256_Fp2_pushforward_payload_bytes=4096,
        notes='Per-column pushforwards are an illustrative UNBATCHED design, not required or minimum. Shared points/batching need a construction.'))
queries=sum(r['U8_queries'] for r in rows);gross_bytes=sum(r['old_U8_H_payload_bytes'] for r in rows)
assert queries==11714560
public_count=ROOT/'results/zk60_1b_native_20261017/r5/bytes_check_8b_T32.txt'
public_phases=ROOT/'results/zk60_1b_native_20261017/r5/PHASES_8B_T32_cli3.md'
count=public_count.read_text();ph=public_phases.read_text()
assert 'H 1758 rows = 14,401,536 words' in count and 'u8 lookups 11,714,560' in count
for p,name in [(public_count,'owner-8b-counts.txt'),(public_phases,'owner-8b-phases.md')]:
    (HERE/'native'/name).write_bytes(p.read_bytes())
pins=json.loads((HERE/'native-pins.json').read_text())
for p,name in [(public_count,'owner-8b-counts.txt'),(public_phases,'owner-8b-phases.md')]:
    pins.append(dict(source=str(p),capture='native/'+name,sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size))
(HERE/'native-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
H=dict(total_base_rows=1758,total_payload_bytes=1758*8192*8,
    U8_reciprocal_data_rows=sum(r['old_U8_H_base_rows'] for r in rows),U8_reciprocal_payload_bytes=gross_bytes,
    exp_act_payload_bytes=16*(sizes['S']+sizes['F']),three_table_payload_bytes=3*16*8192,
    zero_sum_pair_payload_bytes=16*8192,other_reserved_and_proximity_payload_bytes=100*8192*8)
assert H['total_payload_bytes']==sum(H[k] for k in ['U8_reciprocal_payload_bytes','exp_act_payload_bytes','three_table_payload_bytes','zero_sum_pair_payload_bytes','other_reserved_and_proximity_payload_bytes'])

def phase(label):
    line=next(x for x in ph.splitlines() if x.startswith('| '+label+' |'))
    return float(line.split('|')[2])
clocks={k:phase(label) for k,label in {
    'H_commit_s':'H: commit (pcs::commit_zk_owned: encode+Merkle, ONE call)',
    'H_open_s':'open H (schedule audit + pcs::open_zk)',
    'U8_helpers_s':'H: LogUp helper inverses (six lookup domains)',
    'exp_act_helpers_s':'H: exp + activation helper inverses',
    'table_zero_check_s':'slot 19 TAB table helper zero-check',
    }.items()}
total=171.578
# An intentionally impossible free-deletion experiment: every H commit/open
# plus these helper phases is removed, masks and new costs are set to zero.
# This overcredits a U8-only idea and MUST NOT be a forecast.
removed=sum(clocks[k] for k in ['H_commit_s','H_open_s','U8_helpers_s','exp_act_helpers_s'])
clocks.update(total_reported_wall_s=total,free_deletion_four_entire_parent_phases_s=removed,
    idealized_ceiling_ratio=total/(total-removed),idealized_ceiling_positions_per_s=32/(total-removed),
    note='Latest R5 CPU phase diagnostic at capture; fresh cli3 verification not yet observed. Rounded phase sums. This bounds ONLY direct removal of these four measured enclosing phases with ALL else fixed. Does not bound an architecture that also changes other costs. No GPU/5090 or steady-state factor.')
out=dict(status='PASS',scope='COUNTED 8B T32, 32 linked blocks, per-block payload; source-derived geometry matches owner public counters. No native execution.',model='Llama3-8B',context=32,rows=rows,H=H,
    query_value_commitment_already_absent=True,additional_saved_query_commitment_bytes=0,
    illustrative_new_costs=dict(unbatched_U8_pushforwards=sum(cols.values()),all_payload_bytes=sum(cols.values())*4096,
        one_pushforward_if_lifted_to_current_row_width_bytes=16*8192,
        note='256-entry pushforward is 4096 bytes logically; forcing its two base-field limbs into the existing row width is131072 bytes BEFORE masks. New batching/layout may differ. No net commitment saving asserted.'),
    additional_obligations=['ordered original A/affine-index binding including wrapping semantics','support and odd-column padding','all public-table denominator refusals in original schedule','fresh masked GKR messages and hiding pushforward/terminal claims','PCS claims for original index, table and pushforward','new commitment absorb order, M schedule, soundness union and joint-view review','encode/hash/open/serialization, device scratch and transfer cost'],
    phase_diagnostic=clocks,wall_seconds=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,
    completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(HERE/'accounting.json').write_text(json.dumps(out,indent=2)+'\n')
env=dict(cpu=next(x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),platform=platform.platform(),python=platform.python_version(),device='CPU only; no CUDA/GPU calls',threads=1,seed=2026101767,cpu_affinity=list(os.sched_getaffinity(0)),nice=19,estimated_python_mib=96,estimated_compiler_mib=192)
(HERE/'environment.json').write_text(json.dumps(env,indent=2)+'\n')
print(json.dumps(dict(H=H,phase_diagnostic=clocks,illustrative_new_costs=out['illustrative_new_costs']),indent=2))
