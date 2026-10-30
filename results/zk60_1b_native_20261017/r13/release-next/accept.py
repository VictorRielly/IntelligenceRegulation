"""Bounded R13 normal-release gates with source pins and unique run labels."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import os
import re
import shutil
import sys

HERE = Path(__file__).resolve().parents[1]
ROOT = HERE.parents[2]
TREE = HERE / 'working-tree'
MANIFEST = TREE / 'hashline/Cargo.toml'
CARGO = '/home/victor/.cargo/bin/cargo'
spec = importlib.util.spec_from_file_location('sol_r13_runner', ROOT / 'results/zk60_sol_20261026/r13_guard.py')
runner = importlib.util.module_from_spec(spec); spec.loader.exec_module(runner)

def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1<<20),b''):h.update(block)
    return h.hexdigest()

def files():
    names = set(json.loads((HERE.parent / 'r12b/manifest_frozen.json').read_text())['files'])
    for parent, dirs, entries in os.walk(TREE):
        dirs[:] = [d for d in dirs if not d.startswith('target') and d not in ['results','.git']]
        for name in entries:
            p = Path(parent) / name
            if p.suffix in ['.rs','.toml','.lock'] or 'r13_vectors' in p.parts:
                names.add(str(p.relative_to(TREE)))
    return {n:sha(TREE / n) for n in sorted(names)}

def main():
    parser=argparse.ArgumentParser();parser.add_argument('mode',choices=['build','components','proofs','fresh','compat','suite'])
    parser.add_argument('--prefix',required=True);args=parser.parse_args()
    source_path=HERE / f'{args.prefix}.source.json'
    actual=files()
    if source_path.exists(): assert json.loads(source_path.read_text())['files']==actual,'source changed; retain prior attempt'
    else:
        digest=hashlib.sha256(''.join(f'{k} {v}\n' for k,v in actual.items()).encode()).hexdigest()
        source_path.write_text(json.dumps({'tree_sha256':digest,'count':len(actual),'files':actual},indent=2)+'\n')
    def check(): assert files()==actual,'source changed during acceptance'
    def stage(name,kind,need,cap,command,seconds=900,test=False):
        check();label=f'{args.prefix}-{name}';record=HERE / f'{label}.guard.json';done=HERE / f'{label}.done'
        if done.exists():
            data=json.loads(record.read_text());assert done.read_text().strip()=='0' and data['child_rc']==0 and not data.get('guard_killed'),label
        else:
            runner.run(label,kind,need,cap,['/usr/bin/env','RAYON_NUM_THREADS=2','OPENBLAS_NUM_THREADS=1',
                f'ZK60_R12_EVIDENCE_DIR={HERE / "release-r12-receipts"}',
                f'ZK60_NATIVE_TINY_EXPORT_DIR={HERE / "release-tiny-exports"}',
                f'HL_R13_SHIELDSTRAL_EXPORT={HERE / "shieldstral-export-v2"}',*map(str,command)],seconds=seconds)
        check()
        if test:
            text=(HERE/f'{label}.log').read_text()
            counts=re.findall(r'test result: ok\. (\d+) passed; (\d+) failed;',text)
            assert counts and sum(int(p) for p,_ in counts)>0 and all(int(f)==0 for _,f in counts),'test did not execute or failed'
    def cargo(action,*extra): return [CARGO,action,'--release','--offline','--locked','-j2','--manifest-path',MANIFEST,*extra]
    binary_path=HERE/f'{args.prefix}.test-binary.json'
    if args.mode=='build':
        stage('build','build',2.5,5,cargo('test','--lib','--no-run','--message-format=json'))
        events=[]
        for line in (HERE/f'{args.prefix}-build.log').read_text().splitlines():
            if line.startswith('{'):
                try: events.append(json.loads(line))
                except json.JSONDecodeError: pass
        candidates=[x['executable'] for x in events if x.get('reason')=='compiler-artifact' and x.get('executable') and x.get('profile',{}).get('test') and x.get('target',{}).get('name')=='hashline']
        assert len(set(candidates))==1,candidates
        binary_path.write_text(json.dumps({'path':candidates[0],'sha256':sha(Path(candidates[0]))},indent=2)+'\n')
        stage('cli-build','build',2.5,5,cargo('build','--example','zk60_trained_block'))
        return
    info=json.loads(binary_path.read_text());binary=Path(info['path']);assert sha(binary)==info['sha256']
    if args.mode=='components':
        stage('components','cpu',2,4,[binary,'accuracy','--test-threads=1','--nocapture'],test=True)
    elif args.mode=='proofs':
        for suffix,name in [
            ('chain','accuracy_two_stage_private_boundary_with_different_gate_shifts_verifies'),
            ('group-attack','accuracy_wrong_group_table_is_rejected_after_both_honest_contexts_verify'),
            ('receipts','accuracy_dense_low_and_h24_dd_and_non_dd_prove_and_verify'),
            ('norm-attack','accuracy_new_norm_high_byte_mutation_reaches_native_proof_and_is_rejected'),
            ('limb-attacks','accuracy_all_new_limb_and_unused_dictionary_mutations_reach_verification'),
            ('tail-attacks','accuracy_every_table_support_tail_rejects_a_moved_multiplicity'),
            ('actual-import','accuracy_actual_shieldstral_v2_all_public_weights_and_layer_contexts_import')]:
            stage(suffix,'cpu',2.5,4,[binary,'--exact','private_block::accuracy_proof_tests::'+name,'--ignored','--test-threads=1','--nocapture'],test=True)
        stage('goldens','cpu',8,10.5,[binary,'r12_golden_tests','--ignored','--test-threads=1','--nocapture'],seconds=1800,test=True)
    elif args.mode=='compat':
        cli=TREE/'hashline/target/release/examples/zk60_trained_block'
        for suffix in ['tl','8b','tl-dd','8b-dd']:
            old=json.loads((ROOT/f'results/zk60_sol_20261026/r12-compat-{suffix}.command.json').read_text())
            index=next(i for i,arg in enumerate(old) if str(arg).endswith('zk60_trained_block.release.bin'))
            stage('compat-'+suffix,'cpu',2.5 if suffix.startswith('tl') else 3,8,[cli,*old[index+1:]])
        stage('compat-r12-shield','cpu',3,6,['/usr/bin/env',
            f'ZK60_R12_EVIDENCE_DIR={HERE.parent / "r12b/dense-receipts"}',binary,
            'f2_saved_shieldstral','--ignored','--test-threads=1','--nocapture'],test=True)
    elif args.mode=='fresh':
        cli=TREE/'hashline/target/release/examples/zk60_trained_block'
        for name in ['r13-low-dense','r13-h24-wide']:
            original=HERE/'loader-fixtures'/name;public=HERE/'release-exports'/name
            if not public.exists():
                public.mkdir(parents=True);shutil.copyfile(original/'profile.json',public/'profile.json')
                shutil.copytree(original/'layer_00',public/'layer_00')
            assert sha(public/'profile.json')==sha(original/'profile.json')
            assert not list(public.glob('seq_*'))
            for dd in [False,True]:
                suffix=name+('-dd' if dd else '-plain');out=HERE/'release-receipts'/args.prefix/suffix
                out.parent.mkdir(parents=True,exist_ok=True)
                flags=['--dd'] if dd else []
                stage('cli-prove-'+suffix,'cpu',2.5,4,[cli,'prove','--export',public,'--layer','0',
                    '--seq-dir',original/'seq_public','--out',out,'--controls',*flags])
                events=[json.loads(s) for s in (HERE/f'{args.prefix}-cli-prove-{suffix}.log').read_text().splitlines() if s.startswith('{')]
                proved=[x for x in events if x.get('event')=='proved'];assert len(proved)==1
                identity=proved[0]['statement_identity']
                (HERE/f'{args.prefix}-cli-{suffix}.json').write_text(json.dumps({'profile_sha256':sha(public/'profile.json'),
                    'statement_identity':identity,'cli_sha256':sha(cli),'scope':'public synthetic normal-release fixture'},indent=2)+'\n')
                stage('cli-verify-'+suffix,'cpu',2.5,4,[cli,'verify','--export',public,'--layer','0',
                    '--artifact',out,'--expect-statement',identity,'--controls',*flags])
                output=(HERE/f'{args.prefix}-cli-verify-{suffix}.log').read_text()
                assert '"event":"verified"' in output and 'control-refused' in output
    elif args.mode=='suite':
        stage('suite','cpu',4.2,8,cargo('test','--no-fail-fast','--','--test-threads=4'),seconds=1800,test=True)
    check()

if __name__=='__main__':main()
