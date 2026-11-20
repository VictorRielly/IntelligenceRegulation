"""Pass-6 E: which failed-terminal artefacts are pinned in 385 (read-only), plus key pinned files."""
import json, os, re, collections
B = '/Users/victorrielly/IntelligenceRegulation/results/zk60_sol_20261105_w16r3/b3/'
pins = json.load(open(B + 'D78_INDEPENDENT_INTEGRATION_REVIEW_385.json'))['pins']
groups = {
 '359 attempt': 'd78-large-identity359/attempt-000/',
 '359 top': 'd78-large-identity359/',
 '368 attempt': 'd78-correction-bundle368/',
 '373': 'd78-postrun-seal373/',
 '378 attempt': 'd78-large-identity-recovery378/',
 '381': 'd78-identity-finisher381/',
 '386': 'd78-identity-finisher386/',
 '383 dir': 'd78-large-identity-recovery383/',
 '365 dir': 'd78-census-validation365/',
}
for g, pref in groups.items():
    ks = [k for k in pins if k.startswith(pref)]
    print(g, len(ks))
    if g in ('359 attempt', '368 attempt', '373', '378 attempt', '381', '386', '383 dir'):
        for k in ks: print('   ', k)
for name in ('D78_ACTUAL_COMPACT_M_RANK_374.json', 'D78_COMPACT_CRITICAL_INTEGRATION_375.json', 'd78_admission_identity376.py',
             'D78_SYNTHETIC_TIED_IDENTITY_PREPARATION_377.json', 'check_large_identity382.py', 'D78_IDENTITY_PACKAGING_DIAGNOSTIC_384.json',
             'D78_EXTERNAL_REVIEW_REFERENCE_371.json', 'D78_EXTERNAL_EXPORT_STATE_387.json', 'D78_A33_PIN_COMPATIBILITY_388.json',
             'run_large_identity_recovery383.py', 'run_large_identity_recovery378.py', 'check_large_identity379.py',
             'seal_independent_review370.py', 'seal_identity_recovery380.py', 'finish_identity381.py', 'finish_identity386.py', 'finish_correction373.py',
             'seal_identity_packaging385.py', 'seal_compact_critical375.py'):
    print(name, 'PINNED' if name in pins else 'not pinned', (os.path.exists(B + name)))
# source tree pins
print('source trees:', collections.Counter(k.split('/')[0] for k in pins if k.startswith('source-')))
print('rs files pinned', sum(1 for k in pins if k.endswith('.rs')))
