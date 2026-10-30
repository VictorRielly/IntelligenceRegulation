"""One CPU, low priority, <=45s wall / 30s CPU / 256MiB AS per leaf."""
import datetime, json, os, resource, signal, subprocess, sys, time
from pathlib import Path
E = Path(__file__).resolve().parent
mode = sys.argv[1]
assert mode in ("experiment", "audit")


def limits():
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    os.nice(19)
    resource.setrlimit(resource.RLIMIT_CPU, (30, 30))
    resource.setrlimit(resource.RLIMIT_AS, (256 * 1024**2, 256 * 1024**2))
    signal.alarm(40)


env = dict(os.environ, OMP_NUM_THREADS='1', OPENBLAS_NUM_THREADS='1',
           MKL_NUM_THREADS='1', RAYON_NUM_THREADS='1', PYTHONDONTWRITEBYTECODE='1')
cmd = [sys.executable, '-B', str(E / (mode + '.py'))]
start = time.monotonic()
with (E / (mode + '.stdout.log')).open('w') as out, (E / (mode + '.stderr.log')).open('w') as err:
    p = subprocess.run(cmd, stdout=out, stderr=err, env=env,
                       preexec_fn=limits, timeout=45)
rec = dict(command=cmd, utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
           returncode=p.returncode, wall_s=time.monotonic()-start,
           child_maxrss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
           limits=dict(threads=1, cpu_s=30, alarm_s=40, parent_s=45,
                       address_space_mib=256, estimated_memory_mib=64))
(E / (mode + '-execution.json')).write_text(json.dumps(rec, indent=2)+'\n')
with (E / 'commands.jsonl').open('a') as f:
    f.write(json.dumps(rec)+'\n')
print(json.dumps(rec))
print((E / (mode + '.stdout.log')).read_text())
print((E / (mode + '.stderr.log')).read_text())
sys.exit(p.returncode)
