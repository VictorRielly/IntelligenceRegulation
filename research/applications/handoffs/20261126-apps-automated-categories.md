# A17. Which categories dominate automated moderation filings?

On 2 November 2026, **19,316,591 of 25,339,814 statements reporting automated detection (76.23%) gave “other violation of terms and conditions” as their primary category**. That single result crosses A13’s predeclared majority threshold and rules out inferring a specific yes/no policy for most of that day’s automated detections from the category fields alone. Only 6,822 automated detections (0.027%) carried an additional category. [A13 test](20261125-apps-label-need.md#a-test-that-would-confirm-or-kill-the-finding) · [Commission archive](https://transparency.dsa.ec.europa.eu/explore-data/download-file/252663/light)

## What was counted

COUNTED from the Commission’s all-platform daily light archive. I selected the day before inspecting category counts. It contained 30,120,164 statements across 302 CSV files in 31 inner ZIPs. The compressed archive was 1,555,344,992 bytes. Its SHA-1 matched the publisher’s checksum. I read only the four fields used below. The monthly aggregated files omit the additional-category field. [Download table](https://transparency.dsa.ec.europa.eu/explore-data/download) · [Published checksum](https://transparency.dsa.ec.europa.eu/explore-data/download-file/252663/sha1light) · [Commission documentation](https://transparency.dsa.ec.europa.eu/page/api-documentation)

COUNTED below by statement. “Detected” means the filing reported automated detection. “Fully decided” means the filing reported a fully automated decision. A statement can qualify for both. Exactly 13,517,045 did, so the “either” denominator is 25,339,814 + 13,646,725 − 13,517,045 = 25,469,494. Each percentage uses its own column’s denominator.

| Primary category | Detected | Fully decided | Either |
| --- | ---: | ---: | ---: |
| **Statements in group** | **25,339,814** | **13,646,725** | **25,469,494** |
| Other violation of terms and conditions | 76.23% | 82.93% | 76.16% |
| Consumer information | 13.22% | 0.20% | 13.15% |
| Unsafe and prohibited products | 3.05% | 5.32% | 3.11% |
| Illegal or harmful speech | 2.35% | 4.06% | 2.36% |
| Scams and fraud | 1.95% | 2.45% | 2.00% |
| Violence | 1.70% | 2.99% | 1.70% |

COUNTED for the A13 test. “Catch-all” includes the two primary codes in its first two rows. “Additional” means a nonempty JSON category list. Across all filings, 26,601,192 additional fields were blank and 3,511,867 were empty lists.

| Condition | Detected | Fully decided | Either |
| --- | ---: | ---: | ---: |
| `OTHER_VIOLATION_TC` | 19,316,591 | 11,317,631 | 19,397,342 |
| `NOT_SPECIFIED_NOTICE` | 1,462 | 789 | 1,462 |
| Additional | 6,822 (0.027%) | 6,813 (0.050%) | 6,822 (0.027%) |
| Both catch-all and additional | 9 | 6 | 9 |
| **Catch-all or additional** | **19,324,866 (76.26%)** | **11,325,227 (82.99%)** | **19,405,617 (76.19%)** |

## Consequence for the app

DERIVED upper bound for the A13 test is 6,014,948 ÷ 25,339,814 = 23.74% of detected statements had a named primary category and no additional category. Each broad name would still need a validated mapping to a specific policy. A product that promises policy-level evidence would need the underlying rule and its version from the filer, plus a receipt binding that rule to a registered model decision. The installed app can attest to its three classifier verdicts on public content. These filings alone cannot establish that a particular model ran, how many items were screened, whether moderation was correct, or who authored the content.

One day measures filing volume and can be dominated by a large filer. The result leaves other dates and the typical platform open. A replication could select dates in advance and repeat both the statement-level and per-platform-volume-class counts without naming any platform.

## Reproduction

Run the following with Python 3.11 or later, passing the downloaded ZIP as its sole argument. It emits aggregate cells that can be summed for each table column. In the CSV output, primary codes carry the prefix `STATEMENT_CATEGORY_`. The raw archive stays outside the repository. I ran this program against the full archive and cross-checked its 78 aggregate cells against a separate full-file tally. The category totals, additional counts and catch-all unions agreed for all five groups, including the overlap.

```python
import csv, hashlib, io, json, shutil, sys, tempfile, zipfile
from collections import Counter
from functools import lru_cache

@lru_cache(maxsize=256)
def additional(field):
    values = json.loads(field) if field else []
    if not isinstance(values, list) or not all(isinstance(v, str) and v.strip() for v in values):
        raise ValueError("Unexpected additional category encoding")
    return bool(values)

counts = Counter()
with open(sys.argv[1], "rb") as source:
    digest = hashlib.file_digest(source, "sha1").hexdigest()
    assert digest == "4f7936a6eb735d4fef78771a6255f9ed568822a2"
    source.seek(0)
    with zipfile.ZipFile(source) as outer:
        for name in outer.namelist():
            with tempfile.TemporaryFile() as chunk, outer.open(name) as nested:
                shutil.copyfileobj(nested, chunk)
                chunk.seek(0)
                with zipfile.ZipFile(chunk) as inner:
                    for part in inner.namelist():
                        with inner.open(part) as raw, io.TextIOWrapper(raw, encoding="utf-8-sig", newline="") as text:
                            rows = csv.reader(text)
                            fields = next(rows)
                            d, f, c, a = map(fields.index, ("automated_detection", "automated_decision", "category", "category_addition"))
                            for row in rows:
                                counts[row[d] == "Yes", row[f] == "AUTOMATED_DECISION_FULLY", row[c], additional(row[a])] += 1
assert sum(counts.values()) == 30_120_164
out = csv.writer(sys.stdout)
out.writerow(("detected", "fully", "category", "additional", "rows"))
for key, value in sorted(counts.items()):
    out.writerow((*key, value))
```
