import json,os,pathlib,resource,signal,subprocess,sys,time
D=pathlib.Path(__file__).resolve().parent
stage=sys.argv[1]
commands={'prepare':[sys.executable,'-B',str(D/'prepare.py')],'compile':['/usr/bin/rustc','--edition=2021','-C','opt-level=1','-C','codegen-units=1',str(D/'staging.rs'),'-o',str(D/'probe')],'probe':[str(D/'probe')],'audit':[sys.executable,'-B',str(D/'audit.py')],'record':[sys.executable,'-B',str(D/'record.py')],'close':[sys.executable,'-B',str(D/'close.py')]}
def cap():
 os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
 resource.setrlimit(resource.RLIMIT_CPU,(40,40));resource.setrlimit(resource.RLIMIT_AS,(384*1024**2,384*1024**2));signal.alarm(45)
start=time.monotonic()
commands['pin-held']=[sys.executable,'-B',str(D/'pin_held.py')]
commands['finish-reports']=[sys.executable,'-B',str(D/'finish_reports.py')]
with (D/(stage+'.stdout.log')).open('w') as out,(D/(stage+'.stderr.log')).open('w') as err:
 p=subprocess.run(commands[stage],cwd=D,stdout=out,stderr=err,preexec_fn=cap,timeout=50,env={**os.environ,'OMP_NUM_THREADS':'1','RAYON_NUM_THREADS':'1','OPENBLAS_NUM_THREADS':'1','MKL_NUM_THREADS':'1'})
r={'stage':stage,'command':commands[stage],'exit_code':p.returncode,'wall_s':time.monotonic()-start,'max_rss_kib':resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,'one_cpu_affinity':True,'nice':19,'cpu_limit_s':40,'alarm_s':45,'parent_timeout_s':50,'address_space_mib':384,'estimated_memory_mib':300 if stage=='compile' else 96,'gpu':False}
(D/(stage+'-execution.json')).write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r));print((D/(stage+'.stdout.log')).read_text()[:1800] if not p.returncode else (D/(stage+'.stderr.log')).read_text()[-5000:]);raise SystemExit(p.returncode)
