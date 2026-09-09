import hashlib,json,os,subprocess
from pathlib import Path
out=Path('/tmp/zk60-round15/artifact-probe');out.mkdir(exist_ok=True)
(out/'src').mkdir(exist_ok=True);(out/'tests').mkdir(exist_ok=True)
(out/'Cargo.toml').write_text('[package]\nname="artifact-probe"\nversion="0.1.0"\nedition="2021"\n[features]\noptional=[]\n')
(out/'src/main.rs').write_text('fn main() { println!("{}", cfg!(feature="optional")); }\n')
(out/'tests/binary.rs').write_text('#[test] fn built_binary_runs() { assert!(std::process::Command::new(env!("CARGO_BIN_EXE_artifact-probe")).output().unwrap().status.success()); }\n')
env={k:v for k,v in os.environ.items() if not k.startswith("HL_") and k!="CARGO_TARGET_DIR"}
env.update(CARGO_BUILD_JOBS="2",RAYON_NUM_THREADS="2")
base=['cargo'];manifest=['--offline','--manifest-path',str(out/'Cargo.toml')]
logs=[]
def run(name,args,extra=None):
 with (out/(name+'.log')).open('w') as log:
  p=subprocess.run(['flock','/tmp/zk-build.lock']+base+args+manifest,env=dict(env,**(extra or {})),stdout=log,stderr=subprocess.STDOUT,timeout=120)
 assert p.returncode==0
 logs.append(name)
def sha(): return hashlib.sha256((out/'target/release/artifact-probe').read_bytes()).hexdigest()
run('default',['build','--release']);default=sha()
run('shared_feature_tests',['test','--release','--features','optional']);shared=sha()
run('restore_default',['build','--release']);assert sha()==default
run('isolated_feature_tests',['test','--release','--features','optional'],{'CARGO_TARGET_DIR':str(out/'target/storage-tests')});isolated=sha()
r={'synthetic':True,'default_binary_sha256':default,'after_shared_feature_test_sha256':shared,'after_isolated_feature_test_sha256':isolated,'shared_overwrites':shared!=default,'isolated_preserves':isolated==default,'logs':logs}
assert r['shared_overwrites'] and r['isolated_preserves'],r
(out/'result.json').write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps(r,indent=2))
