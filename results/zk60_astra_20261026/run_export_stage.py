"""Bounded, guarded A2 stages, with dependency/HOLD checks and durable logs.

Every invocation is foreground in a yielded tool session. Calibration sources
are never modified by this wrapper. Initial probes are short memory rungs;
continuations require the measured probe record plus a 25 percent margin.
"""
import argparse
import fcntl
import json
from pathlib import Path
import subprocess
import time

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
EXPORT=ROOT/'results/zk60_shieldstral_export_20261026'
GUARD=ROOT/'scripts/zk60_resource_guard.py'
HOLDS=[ROOT/'results/zk60_shieldstral_prep_20261021/HOLD',EXPORT/'HOLD']

def setup(stage):
    if stage=='base':return 'build_export.py',['--max-minutes','25'],EXPORT/'stats_t256/complete.json'
    if stage=='token-io':return 'build_token_io.py',[],EXPORT/'dg_base_t256/layers.complete.json'
    if stage=='s2':return 'evaluation_export.py',['--max-minutes','25'],EXPORT/'dg_base_t256/layers.complete.json'
    if stage=='smoke':return 'evaluate_verdicts.py',['--limit','8','--out',str(EXPORT/'fidelity_smoke8'),'--max-minutes','25'],EXPORT/'s2_evaluation_t256/complete.json'
    raise ValueError('unknown stage')

def main():
    parser=argparse.ArgumentParser();parser.add_argument('stage',choices=('base','token-io','s2','smoke'))
    parser.add_argument('--attempt',type=int,required=True);parser.add_argument('--probe',action='store_true')
    args=parser.parse_args()
    if args.attempt<1:raise ValueError('positive attempt required')
    script,params,dependency=setup(args.stage)
    directory=HERE/'export_jobs'/f'{args.stage}-{args.attempt}'
    directory.mkdir(parents=True,exist_ok=False)
    # A first rung is bounded and uses the closest available measured Python
    # layer working set (fp-diag-v0: 2.42 GiB cgroup; 3.2 includes32%).
    # Token streaming is bounded to512 rows and no block weights in memory.
    need=1.2 if args.stage=='token-io' else 3.2;cap=2.0 if args.stage=='token-io' else 5.0
    if args.attempt>1:
        measured=[]
        for path in directory.parent.glob(args.stage+'-*/guard.json'):
            info=json.loads(path.read_text())
            if info.get('child_rc') in (0,3) and not info.get('guard_killed'):
                measured.append(max(info.get('peak_rss_gib') or 0,info.get('peak_cgroup_gib') or 0))
        if not measured:raise ValueError('a successful measured rung is required before continuation')
        need=round(max(measured)*1.25+.1,2)
    if args.probe:
        if '--max-minutes' not in params:raise ValueError('this streaming stage has no between-layer probe')
        params[params.index('--max-minutes')+1]='0.25'
    (directory/'plan.json').write_text(json.dumps({'stage':args.stage,'attempt':args.attempt,'probe':args.probe,
        'dependency':str(dependency),'need_gib':need,'cap_gib':cap,'threads':2,'scope':'n=1 shared host'},indent=2)+'\n')
    with (directory.parent/(args.stage+'.lock')).open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        while True:
            if dependency.exists() and not any(p.exists() for p in HOLDS):
                check=subprocess.run(['python3',str(GUARD),'check','--class','light','--need-gib',str(need)],capture_output=True,text=True)
                (directory/'precheck.txt').write_text(check.stdout+check.stderr)
                if check.returncode==0 and 'OK to start now' in check.stdout and not any(p.exists() for p in HOLDS):break
            time.sleep(15)
        command=['python3',str(GUARD),'run','--class','light','--need-gib',str(need),'--cap-gib',str(cap),
            '--label','astra-export-'+args.stage,'--wait-secs','60','--max-secs','2400',
            '--log',str(directory/'leaf.log'),'--done',str(directory/'leaf.done'),'--result-json',str(directory/'guard.json'),
            '--','/usr/bin/env','OPENBLAS_NUM_THREADS=2','OMP_NUM_THREADS=2','python3',str(EXPORT/script),*params]
        rc=subprocess.run(command).returncode
        (directory/'worker.done').write_text(str(rc)+'\n');return rc

if __name__=='__main__':raise SystemExit(main())
