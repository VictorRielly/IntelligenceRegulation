"""One low-priority CPU; hard child limits, parent timeout and retained logs."""
import datetime, hashlib, json, os, pathlib, resource, signal, subprocess, sys, time
ROOT = pathlib.Path(__file__).resolve().parent


def limits():
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    os.nice(19)
    resource.setrlimit(resource.RLIMIT_CPU, (30, 30))
    resource.setrlimit(resource.RLIMIT_AS, (256*1024**2, 256*1024**2))
    signal.alarm(30)


name = sys.argv[1]
assert name in ('probe.py', 'audit.py', 'artifact_audit.py')
start = time.monotonic()
with (ROOT/(name+'.stdout')).open('w') as out, (ROOT/(name+'.stderr')).open('w') as err:
    done = subprocess.run([sys.executable, str(ROOT/name)], cwd=ROOT, stdout=out, stderr=err,
                          timeout=35, preexec_fn=limits)
entry = dict(command=[sys.executable, str(ROOT/name)], exit_code=done.returncode,
             elapsed_s=time.monotonic()-start, utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
             sha256=hashlib.sha256((ROOT/name).read_bytes()).hexdigest(),
             threads=1, estimated_memory_mib=64, address_space_mib=256, cpu_seconds=30,
             alarm_seconds=30, parent_timeout_seconds=35, nice=19, affinity='first allowed CPU')
with (ROOT/'commands.jsonl').open('a') as f:
    f.write(json.dumps(entry)+'\n')
print(json.dumps(entry))
if done.returncode:
    print((ROOT/(name+'.stderr')).read_text())
sys.exit(done.returncode)
