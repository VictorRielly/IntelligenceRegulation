"""A small explicit artifact index; never infer liveness from files alone."""
from datetime import datetime,timezone
import hashlib,json
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
items=[
    ('accepted R13 review, separate privacy scope',ROOT/'results/zk60_d24_review_20261017/REVIEW_R13.md'),
    ('S4 design proceed with conditions',ROOT/'results/zk60_d24_review_20261017/S4_DESIGN_CHECK.md'),
    ('native8stream gates, public synthetic',HERE/'NATIVE_STREAM_ACCEPTANCE.json'),
    ('root replay and matched measurements6gates',HERE/'ROOT_AUDIT_MATCHED_CHECKS.json'),
    ('matched R13/R14 synthetic n1 diagnostic',HERE/'MATCHED_R13_R14_COMPARISON.json'),
    ('exact receipt codec count with native serialized crosscheck',HERE/'RECEIPT_TRADEOFF.json'),
    ('fresh root/boundary controls20intended refusals',HERE/'NATIVE_JOINT_CONTROLS.json'),
    ('actualS2L00 strict-model DD/nonDD19sites/proof/fresh/corruption6gates',HERE/'ACTUAL_S2_NATIVE_ACCEPTANCE.json'),
    ('actual26headers conditional backend/no-wrap count, unreviewed',HERE/'ACTUAL_26_LAYER_CONDITIONAL_COUNT.json'),
    ('c2fixture failure diagnosis and correction, no failed proof acceptance',HERE/'C2_FIXTURE_ATTEMPT1.json'),
    ('consolidated candidate2source284pins',HERE/'sol-r14-actual-build-2.source.json'),
    ('native capture design contract, no privacy result',HERE/'NATIVE_CAPTURE_IMPLEMENTATION_CONTRACT.json'),
    ('independent uncompiled capture/L25/regression branch status',HERE/'CAPTURE_BRANCH_STATE.json'),
    ('independent uncompiled observer branch287source pins',HERE/'sol-r14-capture-build-1.source.json'),
    ('reviewer-derived actualL25T128 causal-prefix19site oracle',HERE/'l25-causal-prefix/ORACLE.json'),
    ('original observer pipeline source/script pins and held queue plan, not a result',HERE/'sol-r14-observer-pipeline-1.plan.json'),
    ('approved host recovery audit and held source/script contract',HERE/'recovery-20261030-1/contract.json'),
    ('detached recovery process boot/PID/start identity, check heartbeat before liveness claim',HERE/'recovery-20261030-1/launch.json'),
    ('supplemental M/claim checker18small controls, not native/privacy acceptance',HERE/'SUPPLEMENTAL_CAPTURE_CHECKERS_PREFLIGHT.json'),
    ('condition tracker, author status only',HERE/'CONDITIONS_TRACKER.json'),
]
rows=[]
for description,path in items:
    assert path.is_file(),path
    rows.append({'description':description,'path':str(path.relative_to(ROOT)),
        'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
report={'utc':datetime.now(timezone.utc).isoformat(),'artifacts':rows,
    'source_status':{'last_actual_proof_source':'087016a359c1c0b096f3f131181583f568f7166a476bef3b7c484f181fde5bd9',
        'next_consolidated_test_candidate':'7152ef1a269b2aca5b0ec7ee507a8591db46225466653aaa3113789bfce24262'},
    'retired_tool_handles':[47150,24662,48014],
    'execution_recovery':'Host audit00:18:58Z found original workers absent before heavy leaf. Detached recovery490564 has boot/start identity in recovery-20261030-1/launch.json and5second status heartbeat. Inspect actual evidence; do not relaunch from this index.',
    'pending':['Finish candidate2compile and complete malicious/dense acceptance batch',
        'Remaining old limb/dictionary/support and legacy suite/golden/receipt regressions',
        'Compile/run independent observer branch, actualL25gates and50relation regressions',
        'Exact perCMrank/CFSbudget/NL1/three-stage joint-view adapter; local row precheck is insufficient',
        'Experimental release CLI and complete actual-model integration checks',
        'Whole classifier/token composition and independent R14 bound transfer/review',
        'Freeze then D24 then privacy gate before any profile activation/use'],
    'scope':'Recovery/review index only. No R14 production registration, full26actual proof, classifier integration or privacy acceptance. T256 proof desktop-only. S6 parked.'}
(HERE/'STATUS_ARTIFACT_INDEX.json').write_text(json.dumps(report,indent=2)+'\n')
print('Indexed',len(rows),'explicit R14 artifacts; no liveness or acceptance inferred')
