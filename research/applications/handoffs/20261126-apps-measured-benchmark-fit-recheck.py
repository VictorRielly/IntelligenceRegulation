"""Coordinator's independent count for applications handoff A33 (how many benchmark texts fit the installed app).
Usage: python3 -I -B this.py TEKKEN.json SAMPLES.jsonl.gz TOXIC.csv
Run in an environment that has the mistral_common package; it is NOT the app's environment, and nothing of the app is
imported. The tokenizer is built from the pinned tokenizer file the same way the app builds it (the same library
class); the trimming, the two limits, the chunk counts and the percentiles are written out here independently:
  text = raw.strip(); characters = len(text) (Unicode code points); tokens = encode(" " + text, no BOS, no EOS)
  accepted when characters <= 1000 and tokens <= 336
  proofs for a policy with chunk capacity k and overlap 8: 1 if tokens <= k, else 1 + ceil((tokens - k) / (k - 8))
  capacities 55, 55 and 49; at most 8 chunks each, which is the same condition as tokens <= 336 for the tightest policy
Prints aggregate counts only, as JSON. No text, no token sequence and no per-row value is printed or written."""
import collections
import csv
import gzip
import hashlib
import json
import sys

from mistral_common.tokens.tokenizers.base import TokenizerVersion
from mistral_common.tokens.tokenizers.tekken import Tekkenizer

tek, samples, toxic = sys.argv[1], sys.argv[2], sys.argv[3]
PINS = {'samples': 'ef3f7de86ee394fe337b0a566ba4b9c7db058f3caa8d6a4a0006138b663ab9a8',
        'toxic': '3c2e49889626f7738dca0a29bface0ba0a0595b2ffdd17f0e02f19df7c3c4c9b'}
raw = open(tek, 'rb').read()
model = json.loads(raw)
cfg = model['config']
tok = Tekkenizer(vocab=model['vocab'], special_tokens=model['special_tokens'], pattern=cfg['pattern'],
                 vocab_size=cfg['default_vocab_size'], num_special_tokens=cfg['default_num_special_tokens'],
                 version=TokenizerVersion(cfg['version']), name='coordinator-count')
NSPECIAL = cfg['default_num_special_tokens']
CAPS = (55, 55, 49)
assert max(k + 7 * (k - 8) for k in CAPS) == 384 and min(k + 7 * (k - 8) for k in CAPS) == 336


def chunks(n, k):
    return 1 if n <= k else 1 + -(-(n - k) // (k - 8))


def count(rows):
    t = collections.Counter()
    work = collections.Counter()
    proxy = collections.Counter()
    for r in rows:
        t['rows'] += 1
        text = r.strip()
        if not text:
            t['blank'] += 1
            continue
        ids = tok.encode(' ' + text, bos=False, eos=False)
        assert ids and all(type(i) is int and i >= NSPECIAL for i in ids)
        n = len(ids)
        per = [chunks(n, k) for k in CAPS]
        chars_ok, tokens_ok = len(text) <= 1000, max(per) <= 8
        assert tokens_ok == (n <= 336)
        fits = chars_ok and tokens_ok
        t['fits' if fits else ('both limits' if not chars_ok and not tokens_ok else 'characters only' if tokens_ok else 'tokens only')] += 1
        if fits:
            work[sum(per)] += 1
        for name, cut, actual in (('whole at 1000 characters', 1000, fits), ('one chunk for all three at 196 characters', 196, fits and n <= 49),
                                  ('one chunk for each 55-token policy at 220 characters', 220, fits and n <= 55)):
            t['actual: ' + name.split(' at ')[0]] += int(actual)
            predicted = len(text) <= cut
            if predicted and not actual:
                proxy[name + ': promised by the length rule but not true'] += 1
            if actual and not predicted:
                proxy[name + ': true but missed by the length rule'] += 1
    acc = sum(work.values())
    jobs = sum(k * v for k, v in work.items())
    run, p50, p95 = 0, None, None
    for k, v in sorted(work.items()):
        run += v
        if p50 is None and run * 100 >= 50 * acc:
            p50 = k
        if p95 is None and run * 100 >= 95 * acc:
            p95 = k
    return {'totals': dict(sorted(t.items())), 'accepted': acc, 'planned_proofs': jobs, 'mean_proofs_per_accepted_post': round(jobs / acc, 4),
            'median_nearest_rank': p50, 'p95_nearest_rank': p95, 'proofs_histogram': {str(k): v for k, v in sorted(work.items())},
            'length_rule_errors': dict(sorted(proxy.items()))}


csv.field_size_limit(1 << 30)
out = {'tokenizer_sha256': hashlib.sha256(raw).hexdigest()}
b = open(samples, 'rb').read()
assert hashlib.sha256(b).hexdigest() == PINS['samples']
out['moderation prompts'] = count(json.loads(line)['prompt'] for line in gzip.decompress(b).decode('utf-8').splitlines() if line.strip())
b = open(toxic, 'rb').read()
assert hashlib.sha256(b).hexdigest() == PINS['toxic']
with open(toxic, encoding='utf-8', newline='') as f:
    out['chatbot user messages'] = count(row['user_input'] for row in csv.DictReader(f))
print(json.dumps(out, indent=1))
