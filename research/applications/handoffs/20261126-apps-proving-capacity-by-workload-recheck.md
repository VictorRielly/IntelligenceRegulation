# Coordinator's check of A34 (2026-11-26)

Astra's handoff, [daily proving capacity and download sizes for two measured text workloads](20261126-apps-proving-capacity-by-workload.md), is carried forward: every figure in its two tables and its headline was recomputed.

## How it was checked

[My script](20261126-apps-proving-capacity-by-workload-recheck.py) uses the standard library only and imports nothing of the app. Its [output](20261126-apps-proving-capacity-by-workload-recheck.out.txt) shows 15 checks, all passed.

- **Rates.** From the raw records of the 22 November timing sets (`results/zk60_lane_threads_20261122/raw`, in the repository): six lanes with eight threads each; six legs at the default setting and four each at the two later settings C and D; 14 legs and 756 requests, all proved and checked. Each leg's rate is recomputed from its completion times and equals the recorded rate. The three means are 48.637, 48.963 and 49.997 padded positions a second.
- **Receipt size.** All 756 receipts are 669,561,472 bytes.
- **Segments.** In the three pilot publications of the same 14-token post, each of the nine publication inventories has the digest its signed manifest states, lists 28 segments and adds up to one receipt; the 252 segment hashes are all distinct and add up to 6,026,053,248 bytes. One measured archive is 2,008,826,368 bytes, 141,952 more than its three receipts.
- **Workloads.** Taken from [my own count for A33](20261126-apps-measured-benchmark-fit-recheck.json), not from the handoff's program: 1,680 received, 1,348 eligible and 8,919 requests; 5,083, 4,888 and 18,251.
- **Every derived cell** of the two tables, the headline (4,962 and 8,793 eligible posts a day) and the 21.982 TB a day follow from those inputs.

## Not checked by me

- The signatures of the three manifests. The first one I checked earlier today through the offline example; the other two I did not.
- The handoff's program itself, which imports the app.
- Ten small input files of the second and third pilot runs (their manifests, public keys and publication inventories) are on the project machine only, so the segment check cannot be repeated from the public repository yet.

## Reading

- The three rows of the capacity table are three separate measurements of 22 November. The handoff keeps them apart, and so does the status page.
- The post counts are projections for a prover that is never idle. Queueing, publication, checking, storage and transfer are outside them, and no 24-hour run exists.
- The receipt figures are planned receipts times the measured size of one receipt. Only posts with one chunk per policy have been published and downloaded so far.
