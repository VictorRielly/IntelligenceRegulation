# A31. What a “text” moderation filing tells us

**The EU database records a filer’s choice of media type. It gives no reliable breakdown of text-tagged filings into posts, comments, messages, reviews or listing descriptions, and no distribution of the original text’s length.** The Commission explicitly gives a social post containing text and an image as an example. A filer can also select product or another type. The schema has no dedicated field for those five kinds of writing. [Commission guidance, §§2.1–2.2](https://transparency.dsa.ec.europa.eu/page/documentation) · [API schema](https://transparency.dsa.ec.europa.eu/page/api-documentation)

## What filers actually recorded

COUNTED from the all-platform daily light archive of **2 November 2026**. Two passes agreed on the totals and exact descriptor matches. Of **30,120,164** filed statements, **1,266,513 (4.205%)** carried the text tag. The unit is a filed decision. [Archive](https://transparency.dsa.ec.europa.eu/explore-data/download-file/252663/light) · [Published checksum](https://transparency.dsa.ec.europa.eu/explore-data/download-file/252663/sha1light)

| Among the 1,266,513 text-tagged filings | Statements | Share |
| --- | ---: | ---: |
| Text as the sole media type | 1,185,967 | 93.64% |
| Text and image | 80,341 | 6.34% |
| Text and product | 0 | 0.00% |
| Text and other, with a subtype description | 2,614 | 0.21% |

Rows can overlap. Only 2,614 text-tagged filings supplied a description in `content_type_other`. None of these descriptions mentioned the five forms using the English terms in the reproduction below. Outside the text-tagged set, **302** descriptions exactly matched a post term and **625** exactly matched a comment term. No exact descriptor matched a message, review or listing-description term in either set. This checks one field and a limited English vocabulary. A comment can be filed simply as text, and a listing can contain written material while being filed simply as product. Neither of those quantities can be estimated with these counts. The 625 counts only those self-descriptions outside the text tag.

## Why length is unavailable

The Commission explains that the database omits the underlying moderated item. Its free-text fields describe the decision and its grounds. Kaushal et al. examined more than 131 million filings submitted from 19–28 November 2023 and found templated explanations. Their measurements concern wording supplied by the filer. They give no lengths for the moderated posts. Trujillo et al. studied 353.12 million filings from eight social platforms in the first 100 days ending 2 January 2024. They observed that reported types can describe the target of a restriction, such as an account, even when an individual item prompted the action. Both are findings about submitted statements. [Commission FAQ](https://digital-strategy.ec.europa.eu/en/faqs/dsa-transparency-database-questions-and-answers) · [Kaushal et al., §§4–6](https://research-portal.uu.nl/ws/portalfiles/portal/248230076/3630106.3658960.pdf) · [Trujillo et al., §§3 and 5.4.2](https://arxiv.org/pdf/2312.10269)

**Product consequence.** The day’s text share falls inside A30’s observed monthly range of 3.03–6.82%. Converting that share into prover requests requires original inputs or aggregate token counts by form. A test would take an authorized sample with source form and original length, run the installed tokenizer, and measure how many fit the 49-token limit of the tightest policy and how many require multiple chunks. The share of filings that fit one chunk for each of the three policies remains unknown. Even an item that fits still requires three category proofs. The app can attest to its classifier verdict on the supplied content. Estimating the incoming workload requires the sample. [Monthly counts](20261126-apps-months-check.md) · [Installed policy limits](20261126-apps-installed-policy-lengths.md)

## Reproduction

Run this Python 3.11+ script with the cached daily ZIP as its only argument. The two counts printed for each exact description group are text-tagged and outside the text tag, respectively. The script emits aggregate counts only.

```python
import csv, hashlib, io, json, re, shutil, sys, tempfile, zipfile
from collections import Counter
from functools import lru_cache

groups = {
    'posts': ('post', 'posts', 'social media post', 'social media posts'),
    'comments': ('comment', 'comments'),
    'messages': ('message', 'messages', 'direct message', 'direct messages', 'private message', 'private messages'),
    'reviews': ('review', 'reviews', 'product review', 'product reviews'),
    'listing descriptions': ('listing description', 'listing descriptions', 'product description', 'product descriptions'),
}
terms = {term: group for group, labels in groups.items() for term in labels}

@lru_cache(maxsize=256)
def types(raw):
    result = json.loads(raw)
    assert isinstance(result, list)
    return frozenset(result)

counts = Counter()
matches = Counter()
mentions = Counter()
patterns = {g: re.compile(r'(?<![a-z])(?:' + '|'.join(re.escape(x) for x in labels) + r')(?![a-z])') for g,labels in groups.items()}

@lru_cache(maxsize=256)
def mentioned(value):
    return tuple(group for group,pattern in patterns.items() if pattern.search(value))
with open(sys.argv[1], 'rb') as source:
    assert hashlib.file_digest(source, 'sha1').hexdigest() == '4f7936a6eb735d4fef78771a6255f9ed568822a2'
    source.seek(0)
    with zipfile.ZipFile(source) as outer:
        for member in outer.namelist():
            with outer.open(member) as wrapped, tempfile.TemporaryFile() as chunk:
                shutil.copyfileobj(wrapped, chunk)
                chunk.seek(0)
                with zipfile.ZipFile(chunk) as inner:
                    for part in inner.namelist():
                        with inner.open(part) as raw, io.TextIOWrapper(raw, encoding='utf-8-sig', newline='') as stream:
                            rows = csv.reader(stream)
                            fields = next(rows)
                            typ, other = map(fields.index, ('content_type', 'content_type_other'))
                            for row in rows:
                                labels = types(row[typ])
                                text = 'CONTENT_TYPE_TEXT' in labels
                                desc = row[other].strip().casefold()
                                counts['all'] += 1
                                if text:
                                    counts['text'] += 1
                                    counts['text alone'] += len(labels) == 1
                                    counts['text and product'] += 'CONTENT_TYPE_PRODUCT' in labels
                                    counts['text and image'] += 'CONTENT_TYPE_IMAGE' in labels
                                    counts['text and other'] += 'CONTENT_TYPE_OTHER' in labels
                                    counts['text and descriptor'] += bool(desc)
                                if text and desc:
                                    mentions.update(mentioned(desc))
                                group = terms.get(desc)
                                if group:
                                    matches[group, text] += 1
assert counts['all'] == 30_120_164
print(json.dumps({'counts': counts, 'descriptors': {g: [matches[g,True], matches[g,False]] for g in groups}, 'text descriptor mentions': {g: mentions[g] for g in groups}}, indent=2))
```
