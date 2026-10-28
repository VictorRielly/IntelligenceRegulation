"""Host-side start/status for Astra's detached benchmark queue. Never signals jobs."""
import argparse
import datetime
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
PREP = ROOT / "results/zk60_shieldstral_prep_20261021"
QUEUE = PREP / "tools/astra_host_queue_20261026.sh"
LOGS = PREP / "logs/astra_host_20261026"


def processes():
    found = []
    for p in Path('/proc').iterdir():
        if not p.name.isdigit() or int(p.name) == os.getpid():
            continue
        try:
            args = (p / 'cmdline').read_bytes().split(b'\0')
        except OSError:
            continue
        # Exact executable argument paths, never command-line substring matching.
        targets = {str(f).encode() for f in (QUEUE, PREP/'tools/astra_queue_20261026.sh',
                   PREP/'tools/bench_queue2.sh', PREP/'tools/bench_run.py',
                   ROOT/'scripts/zk60_resource_guard.py',
                   ROOT/'results/zk60_astra_20261026/run_job.py',
                   ROOT/'results/zk60_shieldstral_export_20261026/collect_stats.py',
                   ROOT/'results/zk60_shieldstral_export_20261026/prepare_evaluation.py',
                   ROOT/'results/zk60_shieldstral_export_20261026/smoke_checkpoint.py',
                   ROOT/'apps/proven-media/tools/compile_anchor.py')}
        aliases={os.fsencode(os.path.relpath(os.fsdecode(x),ROOT)):x for x in targets}
        matched=targets.intersection(args)|{aliases[x] for x in args if x in aliases}
        if matched:
            row={'pid': int(p.name), 'matched': [os.fsdecode(x) for x in matched]}
            try:
                fields=(p/'stat').read_text().rsplit(')',1)[1].split()
                ticks=os.sysconf('SC_CLK_TCK');uptime=float(Path('/proc/uptime').read_text().split()[0])
                row.update(cpu_seconds=(int(fields[11])+int(fields[12]))/ticks,
                           elapsed_seconds=uptime-int(fields[19])/ticks,
                           rss_mib=int(fields[21])*os.sysconf('SC_PAGE_SIZE')/(1<<20))
            except (OSError,ValueError,IndexError):pass
            found.append(row)
    return found


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('action', choices=['status', 'start'])
    ap.add_argument('--drain', action='store_true', help='record a read-only S3 process-view check')
    a = ap.parse_args()
    live = processes()
    result = {'at': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'live': live,
              'done': (LOGS/'queue.done').read_text().strip() if (LOGS/'queue.done').exists() else None}
    if a.drain:
        if a.action != 'status': raise SystemExit('--drain is only a status check')
        holds=[PREP/'HOLD',ROOT/'results/zk60_shieldstral_export_20261026/HOLD']
        result['holds_present']=all(p.exists() for p in holds)
        result['no_leaf_or_guard']=not any(any(m != str(QUEUE) for m in row['matched']) for row in live)
        result['queue_at_hold']=result['holds_present'] and result['no_leaf_or_guard']
        result['view']='host /proc argv; reports only matched executable paths, never private input argv'
        (Path(__file__).parent/'s3_host_drain.json').write_text(json.dumps(result,indent=2)+'\n')
    if a.action == 'start':
        if live or result['done'] is not None:
            raise SystemExit('Refusing duplicate/repeated launch: ' + json.dumps(result))
        with (Path(__file__).parent/'bench_host_queue.out').open('ab') as out:
            child = subprocess.Popen(['nohup', 'bash', str(QUEUE)], stdin=subprocess.DEVNULL,
                                     stdout=out, stderr=subprocess.STDOUT, start_new_session=True,
                                     close_fds=True)
        result['started_pid'] = child.pid
        (Path(__file__).parent/'bench_host_launch.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
