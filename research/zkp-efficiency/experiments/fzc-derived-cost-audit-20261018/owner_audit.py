#!/usr/bin/env python3
"""Read aggregate owner diagnostics only; never read/copy proof/witness data."""
from pathlib import Path
import csv,datetime,hashlib,json,re,resource,signal,time
H=Path(__file__).resolve().parent
ROOT=H.parents[3]
OWNER=ROOT/'results/zk60_gpu_zerocheck_20261017'
def main():
 t=time.perf_counter();resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2);resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
 pins=[];rows=[]
 def read(p):
    b=p.read_bytes();pins.append({'path':str(p),'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b)});return b.decode()
 for name in ['s10-r3','s11-r3-warm']:
    q=OWNER/('stack-'+name);log=read(q/'prove.log');pg=json.loads(read(q/'prove.guard.json'))
    events=[json.loads(l) for l in log.splitlines() if l.startswith('{')]
    prove=next(e for e in events if e['event']=='proved')
    gzc=next(e for e in events if e['event']=='gpu_zerocheck')
    row={'name':name,'source_prove_event':prove,'source_gzc_event':gzc,'context':128,'blocks':22,'model':'TinyLlama-1.1B','passes':1,'workload':'single fixed-context stack proof; not resident repeat or decode','owner_threads':16,'guard_prove_seconds':pg['child_wall_seconds'],'peak_vram_mib':pg['peak_vram_mib'],'peak_rss_gib':pg['peak_rss_gib'],'peak_cgroup_gib':pg['peak_cgroup_gib'],'steady_rate':None,'startup_fraction':None,'initial_prefill':None,'serialization':None,'proof_latency':None,'lag_and_drain':None,'scope':'Read-only owner measurements, shared host n1 each. No privacy acceptance; not an8B/P3 target result or local reproduction.'}
    assert pg['exit']==pg['child_rc']==0
    if (q/'verify.log').exists() and (q/'verify.guard.json').exists():
       ve=[json.loads(l) for l in read(q/'verify.log').splitlines() if l.startswith('{')]
       vf=next(e for e in ve if e['event']=='verified');vg=json.loads(read(q/'verify.guard.json'))
       assert vg['exit']==vg['child_rc']==0
       assert vf['statement_identity']==prove['statement_identity'] and vf['receipt_bytes']==prove['receipt_bytes'] and vf['blocks']==prove['blocks']
       row['source_verify_event']=vf;row['guard_verify_seconds']=vg['child_wall_seconds'];row['fresh_process_verified']=True
       row['diagnostic_positions_per_app_second']=128/prove['total_seconds'];row['diagnostic_positions_per_process_second']=128/pg['child_wall_seconds']
    # These are phase fractions, NOT an isolated startup boundary.
    row['load_plus_seal_phase_fraction']=(prove['load_seconds']+prove['sealing_pass_seconds'])/prove['total_seconds']
    build=float(re.search(r'\| build ([0-9.]+) ms',gzc['totals']).group(1))/1000
    body=float(re.search(r'\| total ([0-9.]+) ms',gzc['totals']).group(1))/1000
    row['body_seconds']=body;row['inclusive_build_seconds']=build;row['inclusive_build_fraction_of_body']=build/body
    row['upper_bound_fraction_if_all_slot18_build_free']=build/prove['total_seconds']
    row['upper_bound_rate_if_all_slot18_build_free']=128/(prove['total_seconds']-build)
    row['bound_caveat']='Arithmetic upper bound for this observed run only, assumes all inclusive build work disappears with no added cost or changed overlap. Candidate touches a proper subset; no measured saving or steady8B implication.'
    warm=re.findall(r'PB-GZC-WARM slot 18 \| ([0-9.]+) ms',log)
    row['repeated_spin_seconds']=sum(map(float,warm))/1000
    row['spin_count']=len(warm)
    phases={}
    for l in log.splitlines():
       m=re.match(r'PB-TIMING prove \| (.*?)\s+\| [^|]+\|\s+([0-9.]+) \|',l)
       if m and not m[1].startswith(('SUM','WALL','unaccounted')):phases[m[1]]=phases.get(m[1],0)+float(m[2])
    row['phase_sums_rounded_seconds']=phases
    csvpath=q/'gpu_samples.csv'
    if csvpath.exists():
       lines=read(csvpath).splitlines();row['telemetry_header']=lines[0] if lines else None
       row['telemetry_samples']=len(lines)-1
       row['telemetry_caveat']='CSV retained by owner; policy reason0x20 observed in prior owner reports. No settings altered; no clock-normalized gain inferred.'
    rows.append(row)
 out={'read_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'Aggregate retained owner logs; no receipt files opened or local proof/verification run. Every rate separately labeled1B diagnostic. Queue wait excluded from child/application work; verification separately reported.','rows':rows,'pins':pins,'wall_seconds':time.perf_counter()-t,'rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss}
 (H/'owner-metrics.json').write_text(json.dumps(out,indent=2)+'\n')
 print(json.dumps([{k:v for k,v in r.items() if k in ['name','diagnostic_positions_per_app_second','body_seconds','inclusive_build_seconds','upper_bound_fraction_if_all_slot18_build_free','upper_bound_rate_if_all_slot18_build_free','repeated_spin_seconds','fresh_process_verified','load_plus_seal_phase_fraction']} for r in rows],indent=2))
if __name__=='__main__':main()
