"""One-thread, bounded diagnostic only; neither GPU nor proof timing."""
import datetime,json,os,platform,resource,signal,statistics,subprocess,time
from pathlib import Path
H=Path(__file__).resolve().parent
def main():
    start=time.perf_counter();os.nice(19);cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2);resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    argv=['rustc','--edition=2021','-C','codegen-units=1','-C','opt-level=1','-L',str(H),'-l','dylib=kernels','-C','link-arg=-Wl,-rpath,'+str(H),'bench.rs','-o','bench']
    ct=time.perf_counter();cp=subprocess.run(argv,cwd=H,capture_output=True,text=True,timeout=20)
    (H/'bench-compile.log').write_text(cp.stdout+cp.stderr);assert cp.returncode==0,cp.stderr
    compile_seconds=time.perf_counter()-ct
    bt=time.perf_counter();cp=subprocess.run([str(H/'bench')],cwd=H,capture_output=True,text=True,timeout=25)
    child_seconds=time.perf_counter()-bt;(H/'bench.log').write_text(cp.stdout+cp.stderr);assert cp.returncode==0,cp.stderr
    rows=[json.loads(x) for x in cp.stdout.splitlines()];assert len(rows)==16
    arms={a:[r['nanoseconds']/r['rows'] for r in rows if r['arm']==a] for a in ['baseline','grouped']}
    med={a:statistics.median(v) for a,v in arms.items()}
    out=dict(status='PASS',seed=2026101981,rows=rows,ns_per_row=arms,median_ns_per_row=med,
        paired_speedups=[next(r['nanoseconds'] for r in rows if r['rep']==i and r['arm']=='baseline')/next(r['nanoseconds'] for r in rows if r['rep']==i and r['arm']=='grouped') for i in range(8)],
        median_ratio=med['baseline']/med['grouped'],compiler_argv=argv,compile_seconds=compile_seconds,child_wall_seconds=child_seconds,
        wall_seconds=time.perf_counter()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        child_peak_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,cpu_affinity=[cpu],threads=1,
        finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),platform=platform.platform(),
        scope='Shared-host cache-resident 32 synthetic rows and one arbitrary synthetic parameter pack;8192 rows/sample;8 alternating pairs,256 warmup rows/arm. Exact outputs and checksums agree. Baseline scalar noinline adapters;candidate groups inline native field. No full-D sampler,fold/reduction,model,witness,masks,PCS,serialization,verification,GPU or target rate. Not quiesced/p95.',
        limits='59s CPU/wall,512MiB address space,one nice19 CPU;no Cargo/dependencies/GPU')
    (H/'bench-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({k:v for k,v in out.items() if k not in ['rows','ns_per_row']},indent=2))
if __name__=='__main__':main()
