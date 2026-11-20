"""Pass-6 D: re-compare the 383 checkpoint identities with the saved native 346 cases directly (my own comparison, not Sol's checker); worker hash; 359 primitive report (read-only)."""
import json, hashlib, collections
B = '/Users/victorrielly/IntelligenceRegulation/results/zk60_sol_20261105_w16r3/b3/'
ck = json.load(open(B + 'd78-large-identity-recovery383/native-identities.observed.json'))
q = json.load(open(B + 'd78-large-identity-recovery383/identities.qualification.json'))
want = {p['profile']: p['model_identity'] for p in ck['profiles']}
n = 0; bad = 0
seen = collections.Counter()
for mode in ('outer', 'scaled'):
    cases = json.load(open(B + f'd78-native-admission346/{mode}.sanitized.json'))
    for c in cases:
        if c['profile'] in want:
            n += 1; seen[(mode, c['profile'][-34:], c['registry_checked'])] += 1
            if c['model_identity'] != want[c['profile']]:
                bad += 1
        else:
            print('case profile not in checkpoint', c['profile'])
print('native cases compared directly', n, 'mismatches', bad)
for k, v in sorted(seen.items()): print(' ', k, v)
print('checkpoint status', ck['status'], '| qualification status', q['status'], '| q profiles equal checkpoint', [p['model_identity'] for p in q['profiles']] == [p['model_identity'] for p in ck['profiles']])
sha = lambda p: hashlib.sha256(open(p, 'rb').read()).hexdigest()
print('worker sha (checkpoint)', ck['worker_sha256'][:16], '| on disk', sha(B + 'd78-blake3-356/worker')[:16])
print('recipe sha (checkpoint)', ck['recipe_sha256'][:16], '| 376 on disk', sha(B + 'd78_admission_identity376.py')[:16])
pq = json.load(open(B + 'd78-large-identity359/primitive.qualification.json'))
print('359 primitive status', pq.get('status'), {k: str(v)[:100] for k, v in pq.items() if k not in ('pins', 'status', 'scope')})
bq = json.load(open(B + 'd78-large-identity359/build.qualification.json'))
print('359 build status', bq.get('status'), {k: str(v)[:100] for k, v in bq.items() if k not in ('pins', 'status', 'scope')})
