"""Read-only host liveness and checkpoint inspection for one owned GPU attempt."""
import argparse
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]

def main():
    parser=argparse.ArgumentParser();parser.add_argument('mode',choices=['benchmark','smoke'])
    parser.add_argument('--layer',type=int,required=True);parser.add_argument('--attempt',type=int,required=True)
    args=parser.parse_args();assert 0<=args.layer<26 and args.attempt>0
    directory=HERE/'gpu_replay_jobs'/f'{args.mode}-l{args.layer:02d}-{args.attempt}'
    launch=json.loads(directory.with_suffix('.launch.json').read_text())
    assert launch['boot_id']==Path('/proc/sys/kernel/random/boot_id').read_text().strip(), 'different boot; inspect recovery evidence'
    output=ROOT/'results/zk60_shieldstral_export_20261026'/('fidelity_full_fix1' if args.mode=='benchmark' else 'fidelity_smoke8_gpu')
    processes=[]
    for proc in Path('/proc').iterdir():
        if not proc.name.isdigit():continue
        try:
            argv=[v.decode() for v in (proc/'cmdline').read_bytes().split(b'\0') if v]
            state=(proc/'stat').read_text().split(') ',1)[1].split()[0]
        except (FileNotFoundError,ProcessLookupError,PermissionError,UnicodeError):continue
        if state=='Z':continue
        def option(name,value):return name in argv and argv.index(name)+1<len(argv) and argv[argv.index(name)+1]==value
        role=None
        if int(proc.name)==launch['pid'] and str(HERE/'run_gpu_replay.py') in argv:
            role='launcher'
        elif str(ROOT/'scripts/zk60_resource_guard.py') in argv and option('--result-json',str(directory/'guard.json')):
            role='guard'
        elif str(ROOT/'results/zk60_shieldstral_export_20261026/evaluate_verdicts_gpu.py') in argv and option('--out',str(output)) and option('--layer',str(args.layer)):
            role='leaf'
        if role:processes.append({'pid':int(proc.name),'role':role,'state':state})
    done=directory/'worker.done';terminal=int(done.read_text()) if done.exists() else None
    journal=output/f'layer_{args.layer:02d}/journal.jsonl';rows=[]
    if journal.exists():
        raw=journal.read_bytes();end=raw.rfind(b'\n')+1
        rows=[json.loads(line) for line in raw[:end].splitlines()]
    result={'mode':args.mode,'layer':args.layer,'attempt':args.attempt,'live_processes':processes,'terminal_exit':terminal,
        'durable_items':rows[-1]['end_item'] if rows else 0,
        'observed_refused_items':sum(d['refused'] for r in rows for d in r['diagnostics'])}
    if (directory/'guard.json').exists():
        guard=json.loads((directory/'guard.json').read_text())
        result['guard']={k:guard[k] for k in ('exit','child_rc','peak_rss_gib','peak_vram_mib','gpu_drain_failed','gpu_telemetry_lost')}
    if terminal is None and not processes:
        result['status']='no visible owner process; investigate missing terminal evidence before any restart'
    print(json.dumps(result))

if __name__=='__main__':main()
