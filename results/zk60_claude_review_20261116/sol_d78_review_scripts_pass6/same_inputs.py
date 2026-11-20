"""Pass-6 D: were the native 346 cases and the 354/355 identity inputs identical (by pinned hash) in the 359 (failed), 378 (failed) and 383 (passed) specs? (read-only)"""
import json
B = '/Users/victorrielly/IntelligenceRegulation/results/zk60_sol_20261105_w16r3/b3/'
S = {n: json.load(open(B + f))['pins'] for n, f in (('359', 'D78_LARGE_IDENTITY_BATCH_359_SPEC.json'), ('378', 'D78_LARGE_IDENTITY_RECOVERY_378_SPEC.json'), ('383', 'D78_LARGE_IDENTITY_RECOVERY_383_SPEC.json'))}
keys = ['d78-native-admission346/outer.sanitized.json', 'd78-native-admission346/scaled.sanitized.json', 'd78_admission_identity354.py', 'd78_admission_identity376.py',
        'D78_THREE_SYNTHETIC_ADMISSION_IDENTITY_PREPARATION_355.json', 'd78-blake3-356/worker', 'run_large_identity_leaf358.py', 'check_large_identity379.py', 'check_large_identity382.py']
for k in keys:
    print(k, {n: (p.get(k) or 'absent')[:10] for n, p in S.items()})
