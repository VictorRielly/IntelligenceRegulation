import datetime
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

OUT=Path('/tmp/zk60-round11')
ROOT=Path('/home/victor/IntelligenceRegulation')
LANE=Path('/home/victor/wt-zk60-cl1')
report={'scope':'independent review of Fable GPU fixes, retained validation, privacy analysis and core design',
        'review_pins':{'gpu':'d63c55a','privacy':'daed46f','core':'882f037'},'checks':[]}

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def run(label,argv,cwd):
    log=OUT/(label+'.log')
    with log.open('w') as f:
        p=subprocess.run(argv,cwd=cwd,stdout=f,stderr=subprocess.STDOUT,timeout=90)
    assert p.returncode==0,(label,log)
    report['checks'].append({'name':label,'command':argv,'cwd':str(cwd),'exit_code':p.returncode,'log':str(log),'log_sha256':sha(log)})

run('gpu_python_review',['python3','-m','unittest','discover','-s','tests','-p','test_hashline_cl_*.py'],OUT/'gpu')
run('memory_python_review',['python3','-m','unittest','discover','-s','tests','-p','test_hashline_memory_plan.py'],OUT/'gpu')
run('privacy_rank_review',['python3','-m','unittest','discover','-s','tests','-p','test_zk60_fable_joint_rank.py'],OUT/'privacy')
run('core_graph_review',['python3','zkp-core/tools/dep_closure.py','--out',str(OUT/'core-graph.json'),'--md',''],OUT/'core')
original=OUT/'core/zkp-core/dependency_graph.json'
regenerated=json.loads((OUT/'core-graph.json').read_text())
expected=json.loads(original.read_text())
assert regenerated.pop('baseline')=='unknown' # archive has no .git metadata
baseline=expected.pop('baseline')
assert regenerated==expected
report['core_graph']={'graph_identical':True,'original_sha256':sha(original),
    'baseline_annotation':baseline,'snapshot_baseline_annotation':'unknown (no .git in snapshot)'}

spec=importlib.util.spec_from_file_location('gates',OUT/'gpu/scripts/hashline_cl_gpu_gates.py')
g=importlib.util.module_from_spec(spec);sys.modules['gates']=g;spec.loader.exec_module(g)
report['manifests']=[]
for name in ['cl_round9_floors','cl_round9b_floors']:
    path=LANE/'results'/name/'manifest.json'
    m=json.loads(path.read_text())
    verdict=g.validate_manifest(m,require_production=True)
    assert verdict['ok'],verdict
    logs=[]
    for r in m['cases']:
        log=Path(r['log']['path']);assert sha(log)==r['log']['sha256']
        case=g.case_definition(m['suite_version'],r['id'])
        rebuilt=g.build_case_record(case,m,exit_code=r['exit'],log_text=log.read_text(),log_path=str(log),
              log_sha256=sha(log),argv=r['argv'],proof=r['proof'],binary_sha256=r['binary_sha256'])
        assert rebuilt['ok'],(r['id'],rebuilt['checks'])
        for field in ['verdict','gpu_on','device_label','proof','oracle_summary','wcache','test_results']:
            assert r[field]==rebuilt[field],(r['id'],field)
        logs.append({'case':r['id'],'sha256':sha(log),'checks_rebuilt_from_log':True})
    report['manifests'].append({'path':str(path),'sha256':sha(path),'validation':verdict,'logs':logs})
    if name=='cl_round9b_floors':
        for role,b in m['binaries'].items():
            assert sha(b['path'])==b['sha256']
        assert subprocess.check_output(['git','diff','d63c55a',m['source']['head'],'--','hashline'],cwd=ROOT)==b''
        report['latest_binary_files_match_manifest']=True
        report['latest_gpu_source_equal_to_review_pin']=True
report['observations']=[]
for path in sorted((OUT/'observations').glob('*.json')):
    d=json.loads(path.read_text());assert d['fully_verified'] is True
    assert d['proof_sha256']==path.stem
    assert [r['role'] for r in d['roles']]==(['W','A','H'] if d['privacy']=='P3' else ['A','H'])
    for r in d['roles']:
        n=1<<r['params']['log_cols'];q=r['params']['num_col_checks'];rows=r['commitment']['rows']
        assert len(r['proximity_rhos'])==rows and len(r['proximity_vector'])==n+q
        assert len(r['columns'])==q and all(len(c['values'])==rows for c in r['columns'])
        assert all(len(g['vector'])==n+q for g in r['groups'])
    report['observations'].append({'path':str(path),'sha256':sha(path),'bytes':path.stat().st_size,
        'proof_sha256':d['proof_sha256'],'privacy':d['privacy'],'shape':d['shape'],
        'roles':[{'role':r['role'],'rows':r['commitment']['rows'],'groups':[len(g['members']) for g in r['groups']]} for r in d['roles']]})
assert len(report['observations'])==12
report['caveats']=['Archived proof files were removed by the runner; log/file identities were recorded by that runner. This review rehashes and reparses retained logs and checks current binary files, not deleted proof files.',
    'These manifests validate the Fable source before Codex round10 telemetry and round11 observation changes; a combined integration validation follows.',
    'FA2 stand-in-coefficient model tests are not a completed actual-coefficient rank or simulation review.',
    'No new GPU job was run by this read-only review.']
report['exit_code']=0
(OUT/'review.json').write_text(json.dumps(report,indent=2)+'\n')
print('review complete: 377 GPU/tool tests, 22 rank tests, identical dependency graph, 42 retained case logs, 12 public captures')
