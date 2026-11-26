# Coordinator's check of A33 (2026-11-26)

Astra's handoff, [how many benchmark texts fit the installed classifier](20261126-apps-measured-benchmark-fit.md), is carried forward: an independent count reproduces every counted figure in it.

## How it was checked

- [My script](20261126-apps-measured-benchmark-fit-recheck.py) ran in a separate Python environment (Python 3.12.13, `mistral_common` 1.11.7), not the app's, and imports nothing from the app. It builds the tokenizer from the pinned tokenizer file with the same library class the app uses, and writes out the trimming, the two limits, the chunk counts and the percentiles itself.
- It asserts the same SHA-256 pins for the two retained files as the handoff's program and prints aggregate counts only: [output](20261126-apps-measured-benchmark-fit-recheck.json). No text, token sequence or per-row value was printed or kept.
- [The compare script](20261126-apps-measured-benchmark-fit-recheck-compare.py) derives each figure of the handoff's two tables and of its paragraph on the character rule from my output and looks for it in the handoff: 17 checks, all passed ([output](20261126-apps-measured-benchmark-fit-recheck.out.txt)).

## What this does and does not add

- For the limits, the chunk counts, the totals, the mean and the percentiles, my count is independent of the app's planner.
- For the token IDs it is not independent of the library: I used the same tokenizer class as the app. The handoff's second program, a byte-level encoder written from the vocabulary and the merge list, is the independent check of the IDs. I did not run the handoff's two programs, because they import the app and need its environment.
- Not checked by me: the two source descriptions the handoff cites (the release's README and the paper), and the statement that the file hashes match the project's recovery record. That record, `results/zk60_astra_20261026/mac_evaluation/inputs-recovered.json`, is on the project machine only, so its link in the handoff does not open in the public repository.

## Proofs per accepted text (my count)

| Proofs for one text | Moderation prompts | Chatbot user messages |
| ---: | ---: | ---: |
| 3 | 417 | 4,208 |
| 4 | 62 | 65 |
| 6 | 369 | 261 |
| 7 | 87 | 55 |
| 9 | 186 | 107 |
| 10 | 66 | 52 |
| 12 | 56 | 51 |
| 13 | 43 | 36 |
| 15 | 25 | 22 |
| 16 | 24 | 25 |
| 19 | 4 | 3 |
| 21 | 1 | 0 |
| 22 | 8 | 3 |
| **accepted texts** | **1,348** | **4,888** |

Every accepted text needs at least three proofs, one per policy. Every count is a multiple of three or one more, because the tightest policy (49 content tokens a chunk) reaches its next chunk before the other two do.

## Limits

- Two benchmark files, not a customer's traffic (the handoff says so).
- The counts are planned proofs. No proof was generated, and nothing here measures time or bytes; queue item A34 takes that step.
