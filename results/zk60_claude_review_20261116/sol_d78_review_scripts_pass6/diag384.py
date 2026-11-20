"""Pass-6 D: summarise 384 diagnostic, 375 key fields, 387, 388 (read-only)."""
import json
B = '/Users/victorrielly/IntelligenceRegulation/results/zk60_sol_20261105_w16r3/b3/'
for f in ('D78_IDENTITY_PACKAGING_DIAGNOSTIC_384.json', 'D78_EXTERNAL_EXPORT_STATE_387.json', 'D78_A33_PIN_COMPATIBILITY_388.json', 'D78_EXTERNAL_REVIEW_REFERENCE_371.json'):
    d = json.load(open(B + f))
    print('==', f)
    for k, v in d.items():
        if k == 'pins': print('  pins', len(v)); continue
        print('  ', k, json.dumps(v)[:900])
d = json.load(open(B + 'D78_COMPACT_CRITICAL_INTEGRATION_375.json'))
print('== 375', {k: json.dumps(v)[:200] for k, v in d.items() if k not in ('pins', 'scope', 'successful_guarded_stages')})
