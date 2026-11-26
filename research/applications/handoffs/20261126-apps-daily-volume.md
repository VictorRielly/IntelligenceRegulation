# Daily volume one machine covers against reported moderation volumes (A25)

**Question.** How many requests a day does one machine prove at the installed classifier profile, and how does that compare with the number of statements of reasons the EU transparency database receives? For a named recent period: how many platforms submit in each volume class (under 1,000 a day, 1,000 to 30,000, over 30,000)? Arithmetic: `20261126-apps-daily-volume.py`, output `20261126-apps-daily-volume.out.txt`. The script re-checks every quoted sentence against the downloaded files and prints each file's sha256. Business material: none written; nothing named as a target.

**Answer in one line.** One machine proves about 32,800 to 33,750 requests a day at one request per statement (DERIVED), against about 27 to 31 million statements a day received by all platforms together (SOURCE, labelled below): about 0.11 to 0.12 percent, or 808 to 941 machines for the total. **A class count over all submitting platforms cannot be read from any source I could open**; what I could read is a total, a platform count of 396 with no volumes, and per-platform volumes for eight very large platforms in 2024 only.

## What was read, and how

Local: A18's handoff, the status-page entry and the lane-threads README it cites. Web: raw HTML of eight pages, each downloaded with curl into its own directory (sha256 in the output); the status page was searched with a script, never read whole. Searches: 7 of 12. Page reads: 8 of 12 (the download page, homepage, dashboard, dsa-tdb data-sources page and arXiv 2504.06976 are used for figures; arXiv 2404.02894, a Policy Review article and the announcements page were read and gave no usable figure). No overrun.

## 1. The local rate (MEASURED, 22 November, public posts)

Status page, entry headed "2026-11-23 UTC, speed against the 50 tokens/s target [MEASURED; details and limits in the dated entries further down]", sentence: "The trained 3B classifier that the app runs proves 48.6 to 50.0 tokens/s at six lanes with eight threads each (`results/zk60_lane_threads_20261122/README.md`)."

What it counts, from the README it cites (2026-11-22 UTC): padded tokens per second ("rate = 48 x 128 / (c[L+48] - c[L])"), 48 timed requests on "the eight public posts", six lanes by eight threads, per-thread Metal queues, "the installed W16R2 Shieldstral export", all receipts accepted by the checker. README table: 6x8 level 48.64 (six legs); "Levels over four legs each: X 48.96, Y 50.00, Z 49.70 tok/s." The status page states the per-request cost: "On the installed classifier profile one run of one policy over one chunk takes 2.6 to 2.7 s of the machine's six-lane capacity (128 padded positions at the 47.1 to 50.0 tok/s of the 22 November sets, which are not ranked) and one 0.67 GB receipt." So one request is one chunk window of 128 padded positions under one policy (one category). It is stream capacity, not one request's latency (about 15 to 16 s with all lanes busy, per the same page).

**Profile note.** The status page says the app's deployment file on the project's machine reads "Public content only; privacy not claimed" and production false. Everything below describes what a machine would prove today for public content, not private content.

A later entry (Nov 23, 23:12 UTC, different binary, a "fifth switch", not merged at that entry) says "the installed profile, with this fifth switch, measures about 53 to 55 tok/s on public test posts". It is a different test and is shown in a separate row of the script, never chained with the 22 November figures.

## 2. Platform volumes (what the sources give)

All pages are raw HTML read as text (python3 -I). Statements are counted per period as stated.

| Figure | Period and scope | Source | Read |
|---|---|---|---|
| "4 911 188 424 Total number of statements of reasons submitted" and "396 Number of active platforms" | "the last six months (180 days ...)", all providers; the page does not define "active"; fetched 2026-11-26 | https://transparency.dsa.ec.europa.eu/ (homepage statistics block) | raw text |
| Daily totals, 50 rows, 2026-10-07 to 2026-11-25; sum 1,543,527,638, mean 30,870,553 a day, range 18,994,508 (2026-10-14) to 46,877,410 (2026-11-11) | per day, all platforms together | https://transparency.dsa.ec.europa.eu/explore-data/download (table "Date / Statements of reasons") | raw text |
| 396 platform names in the selector | platforms that can be chosen, not platforms active in a period (the count equals the homepage's 396; the page does not say they are the same set) | same download page | raw text |
| 646.1M, 300.8M, 260.2M, 81.9M, 36.3M, 2.3M, 628K, 293K statements, eight very large social media platforms | March to October 2024 (245 days, my count) | arXiv 2504.06976v1, section "Data": "In detail, our data includes 646.1M SoRs from TikTok, 300.8M from Instagram, 260.2M from Facebook, 81.9M from Pinterest, 36.3M from YouTube, 2.3M from Snapchat, 628K from X, and 293K from LinkedIn." | raw text |

Not usable for a class count: the dashboard page (https://transparency.dsa.ec.europa.eu/dashboard) downloaded as 5,979 characters of help text, with no figures (the charts are script-driven; I did not run it). The dsa-tdb data-sources page (https://dsa.pages.code.europa.eu/transparency-database/dsa-tdb/data_sources.html) says "These aggregated views report the overall count of Statements of Reasons (SoRs) that share the same value in a specific subset of the categorical features" and lists `platform_name` among the aggregation fields, so a per-platform, per-day count can be built from the monthly aggregated files. I did not download any (rule: no datasets; sizes not checked). arXiv 2404.02894 and the Policy Review article give per-platform totals for 2023-24 for a handful of very large platforms only (read, not used for figures). The announcements page gives no platform counts.

**Class counts.**
- All platforms, any recent period: **cannot be read from these sources.** The mean per active platform is 27,284,380 / 396 = 68,900 a day (DERIVED), but the spread is very uneven, so that mean says nothing about how many platforms are in each class.
- Eight very large platforms, March to October 2024, mean a day over the whole period (DERIVED: statements / 245): **5 over 30,000** (2.64 M, 1.23 M, 1.06 M, 334 k, 148 k), **3 in 1,000 to 30,000** (9.4 k, 2.6 k, 1.2 k), **0 under 1,000**. This covers eight platforms, not the 396, and is a period average (a platform could cross a class boundary on single days). It is 2024, not recent.

## 3. Requests one machine proves a day (DERIVED, arithmetic in the output)

Requests a day = tokens/s divided by 128, times 86,400, at one request per statement (one chunk, one category).

| rate (22 Nov sets) | requests a day | statements a day at 3 categories |
|---|---:|---:|
| 48.6 tok/s (status sentence) | 32,805 | 10,935 |
| 50.0 tok/s | 33,750 | 11,250 |

(The README levels 48.64 and 48.96 lie between; the later 53 to 55 tok/s test would give 35,775 to 37,125, shown separately.) Against the totals: 27,284,380 a day (180-day mean) is 808 to 832 machines; 30,870,553 a day (the 50 days above) is 915 to 941 machines; one machine covers 0.11 to 0.12 percent. Of the eight in section 2, the two in the middle class with 1,196 and 2,563 a day need 0.04 and 0.08 of one machine's daily capacity; the one with 9,388 needs 0.28 to 0.29. A platform at the top of that class (30,000 a day) would need 0.89 to 0.91 of one machine (DERIVED: 30,000 / 33,750 and / 32,805).

**Limits (each lowers the figure or narrows its meaning).**
1. One chunk: at T = 128 a request carries 55 (or 49) content tokens after a 72 (or 78) token policy prefix (status page and A22's handoff); a statement longer than one chunk needs J requests, J = 3 to 22 for posts (A18). The share of statements whose content fits is A24's question, unanswered.
2. One category per request; three categories divide by 3, 16 by 16 (A18).
3. Text only: the installed profile is a text classifier. No source read here says what share of statements concern text rather than images, video or listings.
4. Public content only today ("privacy not claimed"); the prover holds the content in the clear. A verdict is a statistical screen and proves nothing about who made content. What a receipt proves: this pinned model, run on this input, gave this verdict.
5. Throughput on eight public posts with the box otherwise idle, one machine state, sustained 24 hours assumed (never run for a day); `/ 128` ignores receipt storage (0.67 GB a request, about 22 TB a day at 33,000 requests, DERIVED: 32,805 x 0.67 GB).

## What a product would have to build

Not built or measured: a per-platform volume census from the aggregated files; a chunking and routing rule for statements longer than one chunk; storage for about 22 TB of receipts a day per machine (or sampling and policy choices that prove only some statements). Nothing in the sources suggests every statement would be proved; any selection is a product decision outside this study.

## A test that would confirm or kill the finding

1. **Class counts:** download one month's `aggregated-simple` file for platform and day (first read its size by a HEAD request; do not fetch if over 20 MB), count platforms with a mean under 1,000, 1,000 to 30,000 and over 30,000 a day over that month. Confirms a class count; if the file exceeds the limit, ask for a size ruling.
2. **Daily capacity:** one timed 24-hour stream on the installed profile at six lanes, public posts, receipts verified. Kill the 33,000 figure if the sustained rate is under 90 percent of the 22 November rate.

## What was not verified

Any per-platform volume for a recent period; what "active" means on the homepage; whether the 396 selector entries and the 396 active platforms are the same set; the dashboard's figures (script-driven, not run); any 24-hour sustained rate; the date of the homepage block beyond the fetch day (the page states none); the share of statements that are text. The aggregated-file sizes were not checked.

## Coordinator's check (2026-11-26)

The co-coordinator downloaded the five pages that carry figures (database homepage, download page, dashboard page, the data-sources documentation page, arXiv 2504.06976v1) and re-ran the script on those copies: the output is identical, the five input hashes included, with 20 of 20 quotations found. The homepage block, the head of the download table and the lane-threads record were re-read in context, and the 50 daily rows were summed again with a separate parser (same sum, lowest and highest). The eight platform names appear in this handoff only inside the cited study's own sentence; nothing here names a target. The question about A28 is answered in the queue item (a download rule). One more figure follows from the handoff's own numbers and is used on the status page: 32,805 requests a day at 669,561,472 bytes a receipt is about 22 TB of receipts a day per machine [DERIVED].
