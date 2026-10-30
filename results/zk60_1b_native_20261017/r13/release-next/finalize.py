"""Audit every final R13 gate before freezing the exact validated source."""
from pathlib import Path
import datetime
import hashlib
import importlib.util
import json
import re
import shutil
import subprocess

HERE=Path(__file__).resolve().parents[1]
TREE=HERE/'working-tree'
PREFIX='release-2'

def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1<<20),b''):h.update(block)
    return h.hexdigest()

def write(path,value):
    temporary=path.with_suffix(path.suffix+'.tmp')
    temporary.write_text(json.dumps(value,indent=2)+'\n');temporary.replace(path)

def main():
    source=json.loads((HERE/f'{PREFIX}.source.json').read_text())
    spec=importlib.util.spec_from_file_location('accept_r13',Path(__file__).with_name('accept.py'))
    accept=importlib.util.module_from_spec(spec);spec.loader.exec_module(accept)
    assert accept.files()==source['files'],'validated source changed'
    names=['build','cli-build','components','chain','group-attack','receipts','norm-attack',
           'limb-attacks','tail-attacks','actual-import','goldens','public-assets','suite']
    names += [f'coverage-{i}' for i in range(9)]
    names += ['compat-'+s for s in ['tl','8b','tl-dd','8b-dd','r12-shield']]
    for fixture in ['r13-low-dense','r13-h24-wide']:
        for dd in ['plain','dd']:
            names += [f'cli-prove-{fixture}-{dd}',f'cli-verify-{fixture}-{dd}']
    expected={f'{PREFIX}-{name}':0 for name in names}
    for dd in ['dd','plain']:
        for mode in ['prove','verify','tamper']:
            label=f'{PREFIX}-actual-t128-{dd}-{mode}'
            expected[label]=1 if mode=='tamper' else 0
            passed=json.loads((HERE/f'{label}.PASS.json').read_text())
            assert passed['passed'] and passed['expected_child_exit']==expected[label]
    records={};evidence={}
    for label,code in expected.items():
        data=json.loads((HERE/f'{label}.guard.json').read_text())
        assert (HERE/f'{label}.done').read_text().strip()==str(code),label
        assert data['exit']==code and data['child_rc']==code and not data.get('guard_killed'),label
        records[label]=data
        for suffix in ['log','command.json','guard.json','done']:
            path=HERE/f'{label}.{suffix}';evidence[path.name]=sha(path)
    counts={}
    for name in ['components','chain','group-attack','receipts','norm-attack','limb-attacks',
                 'tail-attacks','actual-import','goldens','compat-r12-shield','suite']:
        log=(HERE/f'{PREFIX}-{name}.log').read_text()
        matches=re.findall(r'test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored;',log)
        assert matches and all(int(f)==0 for _,f,_ in matches),name
        counts[name]={'passed':sum(int(p) for p,_,_ in matches),'failed':0,
                      'ignored':sum(int(i) for _,_,i in matches),'targets':len(matches)}
        assert counts[name]['passed']>0,name
    assert counts['components']['passed']==77 and counts['goldens']['passed']==5
    assert counts['compat-r12-shield']['passed']==2
    golden=(HERE/f'{PREFIX}-goldens.log').read_text()
    assert len(re.findall('R12-GOLDEN-DIGEST',golden))==4
    assert len(re.findall('R12-GOLDEN-IDENTITY',golden))==5
    for fixture in ['r13-low-dense','r13-h24-wide']:
        for dd in ['plain','dd']:
            rows=[json.loads(s) for s in (HERE/f'{PREFIX}-cli-verify-{fixture}-{dd}.log').read_text().splitlines() if s.startswith('{')]
            assert len([r for r in rows if r.get('event')=='verified'])==1
            controls=[r for r in rows if r.get('event')=='controls']
            assert len(controls)==1 and controls[0]['refused']==19 and controls[0]['honest_still_verifies']
    prior={}
    for revision in ['r8','r9','r12','r12b']:
        directory=HERE.parent/revision;manifest=json.loads((directory/'manifest_frozen.json').read_text())
        frozen=directory/'frozen-tree'
        for name,digest in manifest['files'].items():assert sha(frozen/name)==digest,(revision,name)
        assert {str(p.relative_to(frozen)) for p in frozen.rglob('*') if p.is_file()}==set(manifest['files'])
        prior[revision]=manifest['tree_sha256']
    assets=json.loads((HERE/'PUBLIC_ASSETS.json').read_text())
    for name,data in assets['files'].items():
        path=HERE/name;assert path.stat().st_size==data['bytes'] and sha(path)==data['sha256'],name
    frozen=HERE/'frozen-tree'
    if not frozen.exists():
        staging=HERE/'freeze-building-release-2';staging.mkdir(exist_ok=True)
        for name,digest in source['files'].items():
            target=staging/name;target.parent.mkdir(parents=True,exist_ok=True)
            if target.exists():assert sha(target)==digest,name
            else:shutil.copyfile(TREE/name,target)
        assert {str(p.relative_to(staging)) for p in staging.rglob('*') if p.is_file()}==set(source['files'])
        staging.rename(frozen)
    for name,digest in source['files'].items():assert sha(frozen/name)==digest,name
    assert {str(p.relative_to(frozen)) for p in frozen.rglob('*') if p.is_file()}==set(source['files'])
    utc=datetime.datetime.now(datetime.timezone.utc).isoformat()
    write(HERE/'manifest_frozen.json',{**source,'written_utc':utc,'root':str(frozen),
          'external_public_test_assets':'PUBLIC_ASSETS.json'})
    result=subprocess.run(['diff','-ruN',str(HERE.parent/'r12b/frozen-tree'),str(frozen)],capture_output=True)
    assert result.returncode==1,'R13 must differ from R12b'
    (HERE/'r13-vs-r12b.patch').write_bytes(result.stdout)
    cli=TREE/'hashline/target/release/examples/zk60_trained_block'
    shutil.copy2(cli,HERE/'zk60_trained_block.release.bin')
    binary=json.loads((HERE/f'{PREFIX}.test-binary.json').read_text())
    assert sha(Path(binary['path']))==binary['sha256']
    shutil.copy2(binary['path'],HERE/'hashline.tests.release.bin')
    report={'utc':utc,'status':'FROZEN, ready for independent D24 soundness review; not yet accepted',
       'problem':'implement the approved accuracy stacks as native proved relations, keeping all existing profiles byte compatible',
       'result':'12 explicit LOW/LOW+h24 profiles; exact c2 matmul folds, int16 norm/attention, FP12, up int16, h16/h24, ACT3 and DD constraints',
       'source_tree_sha256':source['tree_sha256'],'source_files':source['count'],'base_r12b':prior['r12b'],
       'test_counts':counts,'guard_records':records,'prior_freezes_unchanged':prior,
       'public_assets_tree_sha256':assets['tree_sha256'],'public_assets_count':assets['count'],
       'cli_sha256':sha(cli),'test_binary_sha256':binary['sha256'],
       'profile_contract':{'schema':'zk60-trained-profile-export/2','stack_field':'accuracy_stack',
           'tinyllama':'low-v1','llama3_8b_and_shieldstral':'low-h24-v1','gate_shift':'bound per layer; trusted stage reconstruction',
           'word_domain':'norm/attention full signed16[-32768,32767]; scores and public i8 weights/gains symmetric[-127,127]',
           'silu':'1..4 public groups,4096 raw int16 entries/group; exact verifier-derived scaling before product rounding',
           'coarse_member':'(0,-8) only in the pinned Shieldstral geometry/registry'},
       'verification_scope':{'synthetic':'four dense Low/H24 DD/nonDD receipts; private two-stage boundaries with G20->21;19 native receipt-emitting attacks;four CLI cases with19 fresh-verifier controls each',
           'actual_import':'all26 Shieldstral public layers, both DD contexts, pinned checkpoint and regenerated tied tables',
           'actual_proofs':'actual candidate layer00 at T128 on public synthetic input, DD and nonDD; independent integer-oracle parity, fresh verification and tamper rejection',
           'legacy':'four R9 golden digests,five identities,four retained R8/R9 full stacks,two retained R12 Shieldstral receipts'},
       'review_packet':['NATIVE_LAYOUT_CENSUS.json','NATIVE_COMPARISON.json','NATIVE_BOUND_REVIEW_PROPOSAL.json','LOOKUP_BOUND_PROPOSAL.md','PUBLIC_ASSETS.json'],
       'limits':['Independent D24 soundness verdict pending','No new privacy acceptance','No full26-layer actual trained proof or fidelity claim',
                 'T256 native layouts and public import covered; no local T256 proof claimed',
                 'Streaming R13 fit_the_stages may add a pre-header public-block load pass; timings are shared-host n=1',
                 'Guard enforcement recorded per leaf; watchdog-only is not a kernel memory cap']}
    write(HERE/'R13_AUDIT.json',report)
    write(HERE/'SOL_REPORT_20261029.json',{k:v for k,v in report.items() if k!='guard_records'})
    for name in ['manifest_frozen.json','R13_AUDIT.json','SOL_REPORT_20261029.json','r13-vs-r12b.patch',
                 'zk60_trained_block.release.bin','hashline.tests.release.bin','PUBLIC_ASSETS.json',
                 'NATIVE_LAYOUT_CENSUS.json','NATIVE_COMPARISON.json','NATIVE_BOUND_REVIEW_PROPOSAL.json','LOOKUP_BOUND_PROPOSAL.md']:
        evidence[name]=sha(HERE/name)
    write(HERE/'evidence.sha256.json',evidence)
    (HERE/'FROZEN.txt').write_text(f'{utc}\nR13 {source["tree_sha256"]}\nBase R12b {prior["r12b"]}\nIndependent D24 review pending; no privacy acceptance.\n')
    (HERE/'R13_COMPLETE.done').write_text('0\n')
    print(json.dumps({'source':source['tree_sha256'],'files':source['count'],'tests':counts,'status':report['status']}))

if __name__=='__main__':main()
