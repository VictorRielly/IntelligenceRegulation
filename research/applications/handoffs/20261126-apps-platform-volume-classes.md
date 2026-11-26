# Platforms by volume class in one month of the EU transparency database's aggregated file (A28)

**Question.** From one monthly pre-made aggregated file, how many platforms have a mean under 1,000, from 1,000 to 30,000, and over 30,000 statements of reasons a day, and what share of the month's statements does each class hold? Script `20261126-apps-platform-volume-classes.py`, output `20261126-apps-platform-volume-classes.out.txt` (no clock reading, no path, no platform name; prints each input's sha256 and re-checks every quotation). Business material: none written. No platform is named; no target is recommended.

**Answer in one line (May 2026, the latest month that has a CSV file).** 192 platforms appear. On a 31-day mean: **124 under 1,000, 48 from 1,000 to 30,000, 20 over 30,000** (COUNTED, DERIVED means), holding **0.07 %, 2.39 % and 97.54 %** of the month's 491,248,553 statements. The top five platforms alone hold 81.02 %, and the largest one 56.07 % (COUNTED).

## What was read and how

- Docs page (SOURCE, raw HTML, 24,925 bytes): https://dsa.pages.code.europa.eu/transparency-database/dsa-tdb/data_sources.html. Download page (raw HTML, 213,951 bytes): https://transparency.dsa.ec.europa.eu/explore-data/download. Each fetched with curl into its own new directory; read as text only. Data file: one zip, 1,198,577 bytes, fetched into its own directory, read in memory with `python3 -I` (zipfile, gzip, csv), never extracted. Page reads: 2 of 12. Web searches: 0 of 12.
- **How I found the file.** The docs page gives the file pattern only for Parquet (`.../agg/pqt/.../aggregated-simple-2024-MM-01-parquet.zip`) and a general pattern for both. The CSV address is my inference from that pattern: the same bucket with `agg/csv/` and `-csv.zip`. HEAD requests (curl -sIL): CSV for 2025-11 through 2026-05 returned 200 with sizes 1.11 to 1.26 MB; CSV for 2026-06 through 2026-11 returned 403 (no such file). The Parquet file for 2026-10 exists (887,003 bytes) but was not fetched (rule: no Parquet). So the latest CSV month is **2026-05**, size by HEAD **1,198,577 bytes (about 1.2 MB, under the 20 MB rule)**, last-modified header 1 June 2026. The archive's declared member sizes total 1,210,776 bytes (rule: stop above 300 MB); the two CSV parts hold 92,642 data rows.
- Several HEAD probes were needed (26, all on the same bucket's host, no listing is offered); I stopped probing when a size was found.

## Quoted sentences (all re-found in the downloaded files by the script, 9 of 9)

1. "We provide aggregated data in both CSV and parquet format." (docs page, "Aggregated data")
2. "These aggregated views report the overall count of Statements of Reasons (SoRs) that share the same value in a specific subset of the categorical features." (same section)
3. "The created_at datetime field is truncated (floored) at the day level." (same section, list "In aggregating the data")
4. "The count of SoRs is reported in the count column." (same list)
5. "This version contains the SoRs data aggregated in a way to reproduce the website version of the dashboard" (section "Versions", Limited version); its group-by list includes `platform_name`, `created_at (truncated to day)` and `source_type`.
6. "The aggregated data provisioning is still in an experimentatl phase and are not guaranteed to be up-to-date with the raw data." (section "Aggregated data", warning; the typo is the page's)
7. "You can also download daily aggregates of statements of reasons submissions in csv or Parquet format." (download page, notification)

## What a row counts

One row is one combination of the file's categorical fields (decision, category, content-type flags, decision fields, `platform_name`, day, `source_type`); the `count` column is the number of statements in that combination (SOURCE, quotes 2 and 4). A platform's month total is the sum of `count` over its rows (COUNTED). The file is the "simple" (limited) version, which the page says reproduces the dashboard's grouping. It covers 31 distinct days, 2026-05-01 to 2026-05-31, none missing, one month only (COUNTED). Rows with an unreadable count: 0; rows with an empty platform name: 0 (COUNTED).

## Counts by class (COUNTED from the file; means DERIVED)

Two ways to take a daily mean, because 90 of the 192 platforms are not present on every day (102 are; by days present: 1 day 15, 2 to 7 days 22, 8 to 30 days 53, every day 102):

| class (mean a day) | platforms, total / 31 days | share of month | platforms, total / days present | share of month |
|---|---:|---:|---:|---:|
| under 1,000 | 124 | 0.07 % | 122 | 0.07 % |
| 1,000 to 30,000 | 48 | 2.39 % | 49 | 2.32 % |
| over 30,000 | 20 | 97.54 % | 21 | 97.61 % |

Three platforms change class between the two bases. The 31-day mean is the fairer reading of "statements a day"; the days-present mean overstates a platform that submitted for a few days only. Each basis sums to 192 platforms and 491,248,553 statements (the script prints the check). Boundaries: a mean of exactly 1,000 or 30,000 falls in the middle class (the script's rule).

**DERIVED, against the machine rate of A25** (one request per statement; 32,805 to 33,750 requests a day, a MEASURED rate from the 22 November public-post sets, different test set from this file): the month's mean is 491,248,553 / 31 = 15,846,727 statements a day, about 470 to 483 machines at one request per statement. The 48 middle-class platforms together: 11,733,281 / 31 = 378,493 a day, 11.2 to 11.5 machines. The 124 smallest together: 11,364 a day, 0.34 to 0.35 of one machine. The 20 largest hold 97.54 %, so the demand is in a very small group; a middle-class platform at the top of its class (30,000 a day) needs 0.89 to 0.91 of one machine (A25).

## What a product would have to build

Not built here. A per-statement proof needs the content for each statement, which the database does not carry (it holds reasons, not content, per the pages A25 read; not re-verified here). Any selection, sampling or chunking rule is a product decision outside this study. The class split says where volume sits (nearly all of it in a few very large platforms), not who would buy; that is outside this repository.

## A test that would confirm or kill the finding

Re-run the script on the same file's Parquet twin or on `aggregated-complete-2026-05` (the same month, a different grouping): the platform totals must agree with these (a kill if the class counts differ by more than the three boundary cases). Or sum one platform's rows for one day against the daily dump for that day (a kill if they differ; the daily dump is gigabytes and was not fetched).

## Column names of the file (for A29)

`automated_decision, automated_detection, category, CONTENT_TYPE_APP, CONTENT_TYPE_AUDIO, CONTENT_TYPE_IMAGE, CONTENT_TYPE_PRODUCT, CONTENT_TYPE_SYNTHETIC_MEDIA, CONTENT_TYPE_TEXT, CONTENT_TYPE_VIDEO, CONTENT_TYPE_OTHER, CONTENT_TYPE_LINK, CONTENT_TYPE_ACCOUNT, CONTENT_TYPE_AD, CONTENT_TYPE_STICKER, CONTENT_TYPE_HASHTAG, decision_account, decision_ground, decision_monetary, decision_provision, DECISION_VISIBILITY_CONTENT_REMOVED, DECISION_VISIBILITY_CONTENT_DISABLED, DECISION_VISIBILITY_CONTENT_DEMOTED, DECISION_VISIBILITY_CONTENT_AGE_RESTRICTED, DECISION_VISIBILITY_CONTENT_INTERACTION_RESTRICTED, DECISION_VISIBILITY_CONTENT_LABELLED, DECISION_VISIBILITY_OTHER, platform_name, created_at, source_type, count`. The content-type flags are booleans per row and one statement can carry several, so summing them over-counts against the total (not tested here).

## What was not verified

- That the file matches the raw data: the page says provisioning is "experimentatl" and "not guaranteed to be up-to-date"; no raw dump was fetched. The month is May, not a recent month (June to November have no CSV in the bucket as of the fetch; whether they appear later, or only as Parquet, is unknown).
- That one `platform_name` is one platform (a company could appear under several names, or one name for several services); 192 is a count of distinct strings.
- Why the May mean (15.8 million a day) is lower than the 27 to 31 million a day of the 180-day and 50-day figures in A25: different periods; I did not test whether the aggregated file and the website totals agree.
- The CSV address was inferred (see above), not given by the docs for CSV; the file's integrity beyond its sha256 was not checked against the bucket's `.sha1` (not fetched).
- Statements per platform per day inside the 8-to-30-day group were not examined; boundary cases are three platforms.

## Coordinator's check (2026-11-26)

The co-coordinator re-ran the script on the tick's files (identical output) and compared its inputs with copies fetched separately: the documentation page and the download page have the hashes of the copies fetched for A25, and a second download of the data file has the same SHA-256. The file's address, which the handoff describes but does not print, is `https://d3vax7phxnku8l.cloudfront.net/agg/csv/data/tdb_data/global___full/aggregations/aggregated-simple-2026-05-01-csv.zip`. A HEAD request gives 1,198,577 bytes and a last-modified date of 1 June 2026; the same address for June and for October answers 403. Three things the handoff lists as not verified were then checked (script `20261126-apps-platform-volume-classes-crosscheck.py`, output beside it; usage in its first lines):

1. **Integrity.** The publisher's `.sha1` file for this archive equals the SHA-1 of the downloaded file.
2. **Counts.** A second parser, written separately, gives the same 92,642 rows, 192 platform names, 491,248,553 statements and the same class counts on both bases.
3. **Against the website.** The file's 31 daily totals were compared with the daily table on the database's download page (pages 4 and 5, fetched 2026-11-26): equal on 15 days and within 0.05 percent on every day; the month sums are 491,248,553 (file) and 491,231,345 (table). So the low May mean (15.8 million a day, against 30.9 million over the 50 days to 2026-11-25) is in the website's own table as well: it is a difference between periods, not a gap in the aggregated file.

Carried forward: the class counts and shares, the largest and top-five shares, and the arithmetic against A25's machine rate. One figure is added from these numbers: 124 + 48 = 172 of the 192 names have a 31-day mean of at most 30,000 statements a day, which is under the 32,805 to 33,750 requests a day one machine proves [DERIVED; one request per statement, with A25's limits]. Not carried: the sentence that the database holds reasons and not content (its basis was not re-read for this check). The counts are for May 2026; with the daily total about twice as high in October and November, a recent month may count differently. The apply script searched this handoff, both outputs, the queue item and the coordination entries for every platform name of four or more characters in the file and found none.
