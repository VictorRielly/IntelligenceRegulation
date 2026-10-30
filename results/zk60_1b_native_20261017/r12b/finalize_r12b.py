"""Audit the actual R12b gates and freeze exactly the validated source set."""
import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
NATIVE=ROOT/'ops/zkp-mvp/trained-1b'
STAGES=[name+'-r2' for name in ['build-7','focused-final','source-pins-final','components-final','hash-census-final',
        'tied-final','cli-build-final','margin-fixture-final','margin-policy-final','astra-tables-final','astra-table-bytes-final','norm-tn7-green',
        'golden-final','dense-final','fresh-final','compat-tl-final','compat-8b-final','compat-tl-dd-final','compat-8b-dd-final','suite-final']]
STAGES.append('gpu-cli-final-r2')

def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        while block:=f.read(1<<20):h.update(block)
    return h.hexdigest()

def main():
    assert (HERE/'ACCEPTANCE_STAGES.done').read_text().strip()=='0'
    source=json.loads((HERE/'source_candidate.json').read_text())
    for name,want in source['files'].items():assert sha(NATIVE/name)==want,name
    prior={}
    for revision in ['r8','r9','r12']:
        directory=HERE.parent/revision
        manifest=json.loads((directory/'manifest_frozen.json').read_text())
        for name,want in manifest['files'].items():assert sha(directory/'frozen-tree'/name)==want,(revision,name)
        actual={str(p.relative_to(directory/'frozen-tree')) for p in (directory/'frozen-tree').rglob('*') if p.is_file()}
        assert actual==set(manifest['files']),f'{revision}: frozen file set moved'
        prior[revision]=manifest['tree_sha256']
    records={}
    for name in STAGES:
        data=json.loads((HERE/f'{name}.guard.json').read_text())
        assert (HERE/f'{name}.done').read_text().strip()=='0',name
        assert data['exit']==0 and data['child_rc']==0 and not data.get('guard_killed'),name
        assert data['enforcement'] in ['watchdog-only','cgroup+watchdog'],name
        records[name]=data
    counts={}
    for name in ['focused-final','source-pins-final','components-final','hash-census-final','tied-final','golden-final','dense-final','fresh-final','suite-final']:
        log=(HERE/f'{name}-r2.log').read_text()
        found=re.findall(r'test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored;',log)
        assert found and all(int(f)==0 for _,f,_ in found),name
        counts[name]={'passed':sum(int(p) for p,_,_ in found),'ignored':sum(int(i) for _,_,i in found),'targets':len(found)}
        assert counts[name]['passed']>0,name
    assert counts['golden-final']['passed']==5
    assert counts['dense-final']['passed']==2 and counts['fresh-final']['passed']==2
    golden=(HERE/'golden-final-r2.log').read_text()
    assert len(re.findall(r'R12-GOLDEN-DIGEST \S+ [a-f0-9]{64}',golden))==4
    assert len(re.findall(r'R12-GOLDEN-IDENTITY \S+ [a-f0-9]{64}',golden))==5
    attack=(HERE/'tied-final-r2.log').read_text()
    for text in ['R12B-HONEST','rehashed multiplier forgery rejected','rehashed head forgery rejected']:assert text in attack,text
    focused=(HERE/'focused-final-r2.log').read_text()
    assert re.search(r'every_token_calibration_field_is_bound_by_the_trained_statement \.\.\. ok',focused)
    assert re.search(r'transformed_profile_refuses_export_rope_before_any_layer_read \.\.\. ok',focused)
    assert (HERE/'fresh-final-r2.log').read_text().count('bytes verified; modified segment rejected')==2
    for suffix,blocks in [('tl',22),('8b',32),('tl-dd',22),('8b-dd',32)]:
        command=json.loads((HERE/f'compat-{suffix}-final-r2.command.json').read_text())
        want=command[command.index('--expect-statement')+1]
        events=[json.loads(s) for s in (HERE/f'compat-{suffix}-final-r2.log').read_text().splitlines() if s.startswith('{')]
        verified=[x for x in events if x.get('event')=='verified']
        assert len(verified)==1 and verified[0]['statement_identity']==want and verified[0]['blocks']==blocks,suffix
    reference=json.loads((HERE/'reference_tables.json').read_text())
    policy=json.loads((HERE/'policy_margin_reference.json').read_text())
    assert policy['refused_coordinates']==0 and policy['coordinates']==3072
    astra=json.loads((HERE/'ASTRA_TABLES_CROSSCHECK_r2.json').read_text())
    assert astra['bos_and_classifier_norm_match_profile']
    assert astra['files']['margin_int16.bin']==policy['margin_sha256']
    for suffix,expected in [('fixture',reference),('policy',policy)]:
        output=[json.loads(s) for s in (HERE/f'margin-{suffix}-final-r2.log').read_text().splitlines() if s.startswith('{')]
        assert len(output)==1 and output[0]['margin_sha256']==expected['margin_sha256']
        for key in ['embedding_sha256','head_sha256','multipliers_sha256']:assert output[0][key]==reference[key]
    tn7=[json.loads(s) for s in (HERE/'norm-tn7-green-r2.log').read_text().splitlines() if s.startswith('{')]
    assert len(tn7)==1
    for key in ['embedding_sha256','head_sha256','multipliers_sha256']:assert tn7[0][key]==reference[key]
    frozen=HERE/'frozen-tree'
    if frozen.exists():
        for name,want in source['files'].items():assert sha(frozen/name)==want,name
    else:
        staging=HERE/'freeze-building'
        staging.mkdir(exist_ok=True)
        for name in source['files']:
            target=staging/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(NATIVE/name,target)
        for name,want in source['files'].items():assert sha(staging/name)==want,name
        assert {str(p.relative_to(staging)) for p in staging.rglob('*') if p.is_file()}==set(source['files'])
        staging.rename(frozen)
    assert {str(p.relative_to(frozen)) for p in frozen.rglob('*') if p.is_file()}==set(source['files'])
    manifest={**source,'written_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'root':str(frozen)}
    (HERE/'manifest_frozen.json').write_text(json.dumps(manifest,indent=2)+'\n')
    old=HERE.parent/'r12/frozen-tree'
    # Compare exactly the frozen deliverable, including the unchanged inherited
    # fixtures. No build directories or newly generated run evidence enter it.
    result=subprocess.run(['diff','-ruN',str(old),str(frozen)],capture_output=True)
    assert result.returncode==1,'expected the R12b fixes to differ from R12'
    (HERE/'r12b-vs-r12.patch').write_bytes(result.stdout)
    for name in ['zk60_trained_block','zk60_tied_tables']:
        binary=NATIVE/'hashline/target/release/examples'/name
        shutil.copy2(binary,HERE/f'{name}.release.bin')
    shutil.copy2(NATIVE/'hashline/target-gpu/release/examples/zk60_trained_block',HERE/'zk60_trained_block.gpu.release.bin')
    audit={'utc':manifest['written_utc'],'source_tree_sha256':source['tree_sha256'],'stages':records,'test_counts':counts,
           'prior_freezes_unchanged':prior,'policy_margin_refused_coordinates':0,
           'security_acceptance':'Ready for independent R12b fix review; no new soundness/privacy acceptance claimed',
           'kernel_caps':all(x['enforcement']=='cgroup+watchdog' for x in records.values()),
           'timing_scope':'MEASURED n=1 shared box; guard enforcement recorded per stage',
           'initial_suite_failure':'First run: 593 library cases passed, one hash-call census case failed; original evidence retained. Public/nested module enumeration and SHA-256 classifications corrected before the final complete run.',
           'verification_scope':'All final gates use the same corrected source manifest; full suite uses four test threads, matching the prior measured R12 configuration.'}
    (HERE/'R12B_AUDIT.json').write_text(json.dumps(audit,indent=2)+'\n')
    evidence={str(p.relative_to(HERE)):sha(p) for p in HERE.iterdir() if p.is_file() and p.name!='evidence.sha256.json'}
    (HERE/'evidence.sha256.json').write_text(json.dumps(evidence,indent=2)+'\n')
    (HERE/'R12B_COMPLETE.done').write_text('0\n')
    print(json.dumps({'tree':source['tree_sha256'],'tests':counts,'kernel_caps':audit['kernel_caps']}))

if __name__=='__main__':main()
