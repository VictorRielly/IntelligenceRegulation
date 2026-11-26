# A33. How many benchmark texts fit the installed classifier?

**Of 1,680 OpenAI moderation prompts, 1,348 fit the installed app (80.24%). Of 5,083 ToxicChat user messages, 4,888 fit (96.16%). The median accepted prompt required six proofs in the first set and three in the second.** A guest pilot serving either population would face a different workload at the same number of submissions.

## Measured fit

COUNTED every row in the locally retained files at the revisions recorded by the project. One row is one proposed post. I used the full OpenAI evaluation file’s `prompt` and the full ToxicChat 0124 test CSV’s `user_input`, including rows without human annotations. The count uses no model responses or labels. The ToxicChat authors describe their source as user queries to a chatbot. I read the OpenAI release README and the ToxicChat paper. The pinned ToxicChat README’s web view was unavailable. The cached dataset hashes matched the project’s original recovery record. [OpenAI evaluation release](https://github.com/openai/moderation-api-release/blob/f4ab51b5edd3bfbcb349a56324274235b674e0e4/README.md) · [ToxicChat paper](https://aclanthology.org/2023.findings-emnlp.311/) · [Retained input hashes](../../../results/zk60_astra_20261026/mac_evaluation/inputs-recovered.json)

| Installed preview outcome | OpenAI moderation | ToxicChat test |
| --- | ---: | ---: |
| Fits 1,000 trimmed characters and 336 content tokens | 1,348 (80.24%) | 4,888 (96.16%) |
| Fits one chunk in every policy (≤49 tokens, three proofs) | 417 (24.82%) | 4,208 (82.79%) |
| Fits a single chunk for each of the two 55-token policies | 479 (28.51%) | 4,273 (84.06%) |
| Exceeds character limit only | 114 | 125 |
| Exceeds token limit only | 4 | 2 |
| Exceeds both limits | 214 | 68 |
| Blank after trimming | 0 | 0 |

Shares use all submitted rows as the denominator. I tokenized even the overlength rows to separate the two rejection reasons. The actual submission route can stop at the character check. [Preview and native boundary cases](../../../results/zk60_astra_20261026/app_text_capacity_20261126/README.md)

## Planned proofs and the character shortcut

| COUNTED or DERIVED per accepted post | OpenAI moderation | ToxicChat test |
| --- | ---: | ---: |
| Total planned proofs | 8,919 | 18,251 |
| Mean (total proofs / accepted posts) | 6.62 | 3.73 |
| Median / 95th percentile, nearest rank | 6 / 13 | 3 / 9 |

The four-characters-per-token proxy at 196 characters would promise one chunk per policy for **22** OpenAI and **24** ToxicChat texts that actually need more. It would miss **39** and **83** genuine one-chunk fits. At 220 characters those two error counts are 24 and 39 for OpenAI, 22 and 60 for ToxicChat. A 1,000-character check alone would admit four and two token-overflow rows respectively. The exact planner gives the author both eligibility and proof count before submission. [A24 proxy and assumptions](20261126-apps-post-length-fit.md)

These are exact counts for two benchmark files. Their transfer to social posts, reviews or a particular pilot requires a sample from that population. A pilot operator can compare its aggregate preview histogram with these two distributions. No posts were submitted, no proofs were generated and no raw messages or per-row output were retained for this study. Classifier verdicts concern the pinned model’s statistical screen. These counts measure input fit and planned work only.

## Reproduction

Run the first program from the repository root in the installed app Python environment with assertions enabled. It rehashes both inputs, uses the committed author normalization and native policy registry, and prints aggregate counts. The second program checks every token ID using the separately serialized Hugging Face vocabulary and merge pairs. It independently rebuilds the three chunk counts from their strides and matched the full proof-count histogram on both sets. [App planner](../../../apps/proven-media/proven_media/proof_plans.py) · [Ordinary token encoder](../../../apps/proven-media/proven_media/shieldstral_text.py)

<details><summary>Count with the app planner</summary>

```python
import csv
import gzip
import hashlib
import json
import sys
from collections import Counter
from pathlib import Path

root = Path.cwd()
lane = root / "results/zk60_astra_20261026"
cache = lane / "mac_evaluation/downloads"
sys.path.insert(0, str(root / "apps/proven-media"))
from proven_media.app import MAX_POST_CHARACTERS, post_text
from proven_media.proof_plans import category_work_plan, proof_count
from proven_media.prompting import ContentRefused
from proven_media.shieldstral_text import ShieldstralTextEncoder
from proven_media.w16r2_runtime import Runtime

encoder = ShieldstralTextEncoder(lane / "app_decision_refresh_20261104/tokenizers/tekken.json")
templates = Runtime.templates()
assert MAX_POST_CHARACTERS == 1000
assert sorted((t.chunk_size, t.overlap, t.max_chunks) for t in templates) == [(49,8,8),(55,8,8),(55,8,8)]
pins = {"samples-1680.jsonl.gz": "ef3f7de86ee394fe337b0a566ba4b9c7db058f3caa8d6a4a0006138b663ab9a8",
        "toxic-chat_annotation_test.csv": "3c2e49889626f7738dca0a29bface0ba0a0595b2ffdd17f0e02f19df7c3c4c9b"}

def count(texts):
    totals, work, proxy_errors = Counter(), Counter(), Counter()
    for raw in texts:
        text, error = post_text(raw)
        totals["rows"] += 1
        if not text:
            totals["empty"] += 1
            continue
        n = len(encoder.content_ids(text))
        try:
            proofs = proof_count(category_work_plan(n, templates))
        except ContentRefused:
            assert n > 336
            proofs = 0
        assert bool(proofs) == (n <= 336)
        if not proofs or error:
            reason = "both" if error and not proofs else ("characters" if error else "tokens")
            totals[reason] += 1
        else:
            work[proofs] += 1
            totals["fit"] += 1
        for name, chars, actual in [("whole",1000, bool(proofs) and not error),
                                    ("all49",196, not error and n <= 49),
                                    ("each55",220, not error and n <= 55)]:
            totals[name] += int(actual)
            predicted = len(text) <= chars
            if predicted != actual:
                proxy_errors[(name, "over" if predicted else "under")] += 1
    return {"totals": dict(totals), "proofs_per_accepted_post": dict(sorted(work.items())),
            "proxy_errors": {"/".join(key): value for key,value in sorted(proxy_errors.items())}}

for name, digest in pins.items():
    path = cache / name
    assert hashlib.sha256(path.read_bytes()).hexdigest() == digest
    if name.endswith(".gz"):
        with gzip.open(path, "rt", encoding="utf-8") as f:
            result = count(json.loads(line)["prompt"] for line in f)
    else:
        with path.open(encoding="utf-8", newline="") as f:
            result = count(row["user_input"] for row in csv.DictReader(f))
    print(name, json.dumps(result, sort_keys=True))
```

</details>

<details><summary>Check token IDs and proof counts independently</summary>

```python
"""Recount with the Hugging Face vocabulary, ordinary byte BPE and integer geometry."""
import csv
import gzip
import hashlib
import json
import sys
from collections import Counter
from functools import lru_cache
from pathlib import Path

import regex

root = Path.cwd()
lane = root / "results" / "zk60_astra_20261026"
cache = lane / "mac_evaluation/downloads"
ref = cache / "tokenizer.json"
assert hashlib.sha256(ref.read_bytes()).hexdigest() == "9172cf28b79a17502736f971b560faeced38ee527540cea6882a1f40cce320c0"
config = json.loads(ref.read_bytes())
model = config["model"]
assert model["ignore_merges"] is True
pattern = regex.compile(config["pre_tokenizer"]["pretokenizers"][0]["pattern"]["Regex"])
vocab = model["vocab"]
rank = {tuple(pair): i for i,pair in enumerate(model["merges"])}
visible = list(range(33,127)) + list(range(161,173)) + list(range(174,256))
bytechar = {n: chr(n) for n in visible}
missing = [n for n in range(256) if n not in bytechar]
bytechar.update((n,chr(256+i)) for i,n in enumerate(missing))

@lru_cache(maxsize=16384)
def encode_piece(piece):
    encoded = "".join(bytechar[b] for b in piece.encode())
    if vocab.get(encoded, -1) >= 1000:
        return (vocab[encoded],)
    symbols = list(encoded)
    while len(symbols) > 1:
        pairs = zip(symbols, symbols[1:])
        priority, pos = min((rank.get(pair, len(rank)), k) for k,pair in enumerate(pairs))
        if priority == len(rank):
            break
        symbols[pos:pos+2] = [symbols[pos] + symbols[pos+1]]
    return tuple(vocab[s] for s in symbols)

sys.path.insert(0, str(root / "apps/proven-media"))
from proven_media.shieldstral_text import ShieldstralTextEncoder
encoder = ShieldstralTextEncoder(lane / "app_decision_refresh_20261104/tokenizers/tekken.json")

def audit(rows):
    hist, demand, matrix = Counter(), Counter(), Counter()
    for i,raw in enumerate(rows):
        text = raw.strip()
        if not text:
            hist["empty"] += 1
            continue
        source = " " + text
        pieces = pattern.findall(source)
        assert "".join(pieces) == source
        ids = tuple(idx for piece in pieces for idx in encode_piece(piece))
        assert ids == encoder.content_ids(text), ("token IDs differ at row", i + 1)
        n = len(ids)
        per_policy = [1 + max(0, (n-k + (k-8)-1)//(k-8)) for k in (49,55,55)]
        char, token = len(text) <= 1000, max(per_policy) <= 8
        fits = char and token
        hist["fit" if fits else ("both" if not char and not token else "tokens" if char else "characters")] += 1
        if fits:
            demand[sum(per_policy)] += 1
        for name,cut,exact in (("whole",1000,fits),("all49",196,fits and n<=49),("each55",220,fits and n<=55)):
            matrix[name, len(text)<=cut, exact] += 1
    print("identical_token_sequences",i+1-hist["empty"],"outcomes",dict(hist),"proofs", dict(sorted(demand.items())))
    for k in ("whole","all49","each55"):
        print(k, "predicted_only",matrix[k,True,False],"actual_only",matrix[k,False,True], "actual",matrix[k,True,True]+matrix[k,False,True])
    total=sum(demand.values()); running=0; p50=p95=None
    for jobs, posts in sorted(demand.items()):
        running+=posts
        if p50 is None and running*100 >= 50*total: p50=jobs
        if p95 is None and running*100 >= 95*total: p95=jobs
    jobs=demand.total() and sum(k*v for k,v in demand.items())
    print("total_jobs", jobs, "mean",jobs/total,"p50",p50,"p95",p95)

with gzip.open(cache/"samples-1680.jsonl.gz","rt",encoding="utf-8") as f:
    audit(json.loads(row)["prompt"] for row in f)
with (cache/"toxic-chat_annotation_test.csv").open(encoding="utf-8",newline="") as f:
    audit(row["user_input"] for row in csv.DictReader(f))
```

</details>
