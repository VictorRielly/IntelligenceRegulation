# A34. Daily proving capacity and download sizes for two measured text workloads

**One six-lane Mac has a projected proving budget of about 4,962 eligible posts per day for the OpenAI moderation mix or 8,793 for the ToxicChat mix.** Both estimates use the same November 22 thread-setting measurement. The difference comes from how many policies and chunks each text requires. These are projections for a continuously occupied prover. A 24-hour app publication rate remains unmeasured.

## A machine-day at the installed classifier profile

MEASURED inputs from November 22, W16R2 Shieldstral at T128 with six lanes and eight threads each. I recomputed each leg’s rate from completion timestamps and checked the receipt outcomes. Across the 14 selected legs, all 756 requests including warm-up were proved and checked. The driver repeatedly submitted chunk zero for one policy on eight public fixtures. The timed window covers 48 completions after six warm-ups per leg. The verifier ran separately outside that window. [Driver](../../../results/zk60_lane_threads_20261122/composed_driver.py) · [Fixtures and policy](../../../results/zk60_lane_threads_20261122/t1_driver.py) · [Measured settings and decision](../../../results/zk60_lane_threads_20261122/README.md)

DERIVED counts below are rounded at the end. “Received” counts incoming texts at the benchmark’s observed fit fraction. “Eligible” counts texts that fit the author’s character gate and the three token plans. A rejected input consumes zero native requests in this calculation. The OpenAI file contributed 1,680 received / 1,348 eligible / 8,919 requests. The ToxicChat split contributed 5,083 / 4,888 / 18,251. [A33 counts and histograms](20261126-apps-measured-benchmark-fit.md)

| Measured batch and setting | Padded positions/s | Native requests/day | OpenAI received / eligible per day | ToxicChat received / eligible per day |
| --- | ---: | ---: | ---: | ---: |
| Six thread-setting legs, defaults | 48.637 | 32,830 | 6,184 / 4,962 | 9,143 / 8,793 |
| Four later tail-round legs, default C | 48.963 | 33,050 | 6,225 / 4,995 | 9,205 / 8,851 |
| Same later comparison, experimental D | 49.997 | 33,748 | 6,357 / 5,101 | 9,399 / 9,038 |

Requests/day = mean padded positions/s × 86,400 / 128. Multiply by received texts / total requests or eligible texts / total requests for the two post counts. The experimental tail setting fell short of the predeclared gain threshold. The rows describe separate measurements and settings. Queue gaps, submission checks, activation preparation, publication, rechecks, storage and transfer all require additional capacity. [Earlier request-only arithmetic](20261126-apps-daily-volume.md)

## How much would a guest download?

MEASURED in those same native records, all 756 receipts were 669,561,472 bytes each. Separately, I authenticated three pilot manifests with their recorded development keys and matched the nine signed inventory digests. Together they listed **252 distinct segment hashes and 6,026,053,248 bytes**, with no segment hash shared across the three publications of the same 14-token fixture. In one measured tar download, the 84 unique segments occupied 2,008,684,416 bytes. The complete store download was 2,008,826,368 bytes. Its other objects, ledger and tar framing accounted for the remaining 141,952 bytes. The November 25 publisher run stopped before its guest checks, which subsequently passed in a separate run. [Archive measurement](../../../results/zk60_astra_20261026/app_composed_native_20261122/DOWNLOAD_RESUME.json) · [Guest replay](../../../results/zk60_astra_20261026/app_composed_native_20261122/guest-20261125T073308.630547Z/RESULT.json)

| DERIVED logical receipt data at the observed bytes per request | OpenAI moderation | ToxicChat |
| --- | ---: | ---: |
| Mean per eligible text | 4.430 GB | 2.500 GB |
| Median per eligible text | 4.017 GB (6 receipts) | 2.009 GB (3 receipts) |
| 95th percentile per eligible text | 8.704 GB (13 receipts) | 6.026 GB (9 receipts) |
| All eligible texts in the source file | 5.972 TB | 12.220 TB |

Logical bytes sum all planned receipts before content-addressed deduplication. At the first row’s native rate, sustained generation would yield 21.982 decimal TB/day. An actual offline archive includes each distinct object once and adds statements, ledger history and tar framing. Only the single-chunk-per-policy guest transfers were measured here. Metadata and deduplication for a longer post depend on its actual receipts and ledger. The full native model kit is reusable across posts. A signature-only download has its own smaller size and authenticates the publisher’s signed labels. [Archive construction](../../../apps/proven-media/proven_media/public_store_download.py) · [Guest workflow](20261124-apps-receipt-size.md)

**Deciding observation.** Publish a public text of 50–55 tokens on the installed profile. The planner calls for four receipts because the 49-token policy needs a second chunk. Count segment references and distinct hashes, read the exact archive length, then verify all four statements against the downloaded store. A 24-hour capacity claim separately needs a sustained run recording received, refused, published and verified counts alongside storage growth. Proofs attest to the pinned classifier’s computation. Human authorship requires separate evidence.

<details><summary>Reproduce from the repository root with the installed app Python environment</summary>

The program uses the raw native legs, checks the signed inventories and reuses A33’s pinned counting program on the two retained datasets. It prints aggregates only.

```python
import hashlib
import json
import math
import re
import statistics
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

root = Path.cwd()
lane = root / "results/zk60_lane_threads_20261122/raw"
pilot = root / "results/zk60_astra_20261026/app_composed_native_20261122"
sys.path.insert(0, str(root / "apps/proven-media"))
from proven_media.manifest import verify_signature

def read(path):
    return json.loads(path.read_bytes())

rates = defaultdict(list)
receipt_sizes = set()
for group in ("lt_set2", "lt_set2b", "lt_set3", "tr_set1", "tr_set1b"):
    for leg in read(lane/group/"t2_results.json")["legs"]:
        if (leg["lanes"], leg["threads"]) != (6, 8):
            continue
        arm = "6x8" if group.startswith("lt") else leg["arm"]
        if arm == "E":
            continue
        c = leg["completions"]
        assert (leg["N"], leg["timed"], len(c)) == (6,48,54)
        assert leg["verified_by_B0"] and leg["verify_summary"] == {"receipts":54,"checked":54,"other":0}
        assert all(x["status"] == "proved" for x in c)
        assert {x["q"] for x in c} == {x["q"] for x in leg["verified"] if x["status"]=="checked"} == set(range(54))
        rate = 48 * 128 / (c[-1]["t_abs"] - c[5]["t_abs"])
        assert math.isclose(rate, leg["rate"], rel_tol=1e-8)
        rates[arm].append(rate)
        receipt_sizes.update(x["receipt_bytes"] for x in c)
assert {k:len(v) for k,v in rates.items()} == {"6x8":6,"C":4,"D":4}
assert receipt_sizes == {669561472}
receipt = receipt_sizes.pop()

all_segments = {}
for tag in ("20261124T082610.220713Z", "20261124T183850.945359Z", "20261125T070919.014403Z"):
    run = pilot / ("qualification-" + tag)
    signed = read(run/"manifest.json")
    key = read(run/"publisher_public_key.json")["public_key"]
    assert verify_signature(signed,key)["accepted"] and signed["item"]["content_length_tokens"]==14
    for entry in signed["entries"]:
        raw = (run/(entry["category"]+".publication.json")).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == entry["bundle"]["manifest_sha256"]
        inv = json.loads(raw)
        assert inv["statement_sha256"] == entry["statement_sha256"] and len(inv["segments"]) == 28
        assert sum(s["bytes"] for s in inv["segments"]) == receipt
        for s in inv["segments"]:
            assert s["sha256"] not in all_segments
            all_segments[s["sha256"]] = s["bytes"]
assert len(all_segments)==252
archive = read(pilot/"DOWNLOAD_RESUME.json")
assert archive["passed"] and archive["bytes"]==2008826368
print("unique segments across three publications",len(all_segments),sum(all_segments.values()))
print("one archive's additional bytes", archive["bytes"]-3*receipt)

study=root/"research/applications/handoffs/20261126-apps-measured-benchmark-fit.md"
code=re.findall(r"```python\n(.*?)```",study.read_text(),re.S)[0]
assert hashlib.sha256(code.encode()).hexdigest()=="f839a2467afad24f97344af8267eadfa7498e728c58cea3399a63ebd1b4178e5"
rows=subprocess.run([sys.executable,"-IB","-"],input=code,text=True,capture_output=True,check=True).stdout.splitlines()
assert len(rows)==2
for row in rows:
    name,record=row.split(" ",1)
    j=json.loads(record)
    hist=sorted((int(k),v) for k,v in j["proofs_per_accepted_post"].items())
    accepted=sum(count for k,count in hist)
    total=j["totals"]["rows"]
    jobs=sum(k*count for k,count in hist)
    assert j["totals"]["fit"]==accepted
    print(name, "submitted/eligible/requests", total, accepted, jobs)
    print("logical receipt GB mean", round(jobs*receipt/accepted/1e9,3),
          "whole-file TB", round(jobs*receipt/1e12,3))
    for q in (0.5,0.95):
        target=math.ceil(q*accepted)
        for k,count in hist:
            target-=count
            if target<=0:
                print(q,"proofs/GB",k,round(k*receipt/1e9,3))
                break
    for arm,values in rates.items():
        calls=statistics.mean(values)*86400/128
        print(arm,"native requests / received / eligible per day",
              *(round(v) for v in (calls,calls*total/jobs,calls*accepted/jobs)),
              "logical TB/day",round(calls*receipt/1e12,3))
```

</details>
