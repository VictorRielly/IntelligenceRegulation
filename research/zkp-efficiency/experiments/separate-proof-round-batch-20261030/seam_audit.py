from pathlib import Path
import hashlib, json, subprocess
D=Path(__file__).resolve().parent;P=D.parents[3]
F=P/'results/zk60_1b_native_20261017/r13/frozen-tree'
pins=json.loads((D/'native-pins.json').read_text())
for sub in ['zkp-core/src/sumcheck.rs','zkp-core/src/field.rs','zkp-core/src/transcript.rs',
            'zkp-core/src/sumcheck/rounds.rs','zkp-core/src/sumcheck/grouped.rs',
            'hashline/src/zk.rs','hashline/src/gpu/cuda.rs']:
    f=F/sub;b=f.read_bytes();name='r13_'+sub.replace('/','__');(D/'native'/name).write_bytes(b)
    pins=[x for x in pins if x['path']!=str(f)]
    pins.append(dict(path=str(f),snapshot='native/'+name,bytes=len(b),sha256=hashlib.sha256(b).hexdigest()))
def cfs(t):return t[t.index('#[derive(Clone, Debug)]\npub struct CfsMask'):t.index('/// The transcript masker')]
checks={'root_r13_field_equal':(P/'zkp-core/src/field.rs').read_bytes()==(F/'zkp-core/src/field.rs').read_bytes(),
        'root_r13_cfs_equal':cfs((P/'zkp-core/src/sumcheck.rs').read_text())==cfs((F/'zkp-core/src/sumcheck.rs').read_text())}
a=(F/'hashline/src/private_block/argument.rs').read_text();rs=(F/'zkp-core/src/sumcheck/rounds.rs').read_text()
checks.update({'round_interface_unmasked_contract':'returns UNMASKED evaluations' in rs,
    'driver_absorb_challenge_fold_order':rs.index('tr.absorb_fp2(b"sc-round", &sums);')<rs.index('let r = tr.challenge_fp2();')<rs.index('ev.fold(r);'),
    'argument_uses_typed_rounds':'crate::zk::masked_prove_rounds' in a,
    'argument_direct_legacy_gpu_calls':a.count('dev_zerocheck_blocks')+a.count('dev_tab_zerocheck')})
assert all(checks[k] for k in ['root_r13_field_equal','root_r13_cfs_equal','round_interface_unmasked_contract','driver_absorb_challenge_fold_order','argument_uses_typed_rounds'])
for pattern,target,outfile in [('dev_zerocheck_blocks|dev_tab_zerocheck',F/'hashline/src','legacy-gpu-callsite-screen.txt'),
    ('impl.*SumcheckRounds|fn prove_rounds',F/'zkp-core/src/sumcheck','round-interface-screen.txt')]:
    call=subprocess.run(['rg','-n',pattern,str(target)],text=True,capture_output=True);assert call.returncode==0
    (D/outfile).write_text(call.stdout)
checks['scope']='Inspected R13 argument -> masked_prove_rounds -> prove_rounds -> ClosureRounds/GroupedEqRounds; no current private block port to legacy GPU API established. Not a general reachability proof.'
(D/'native-seam-check.json').write_text(json.dumps(checks,indent=2)+'\n');(D/'native-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
print(json.dumps(checks))
