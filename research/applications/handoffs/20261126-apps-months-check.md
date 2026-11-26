# The class counts and the text share over seven months (A30)

**Question.** A28 counted platform names by volume class, and A29 the share of statements with the text content
type, both for May 2026 only. Do the two findings hold in the other months for which the EU transparency database
offers a monthly aggregated CSV? Done by the co-coordinator as a local count (no agent). Script
`20261126-apps-months-check.py`, output `20261126-apps-months-check.out.txt` (prints each input's sha256 and no
clock reading, no path and no platform name). Business material: none written. No platform is named; no target is
recommended.

**Answer in one line.** Both hold in all seven months, November 2025 to May 2026. The text share is between 3.03 and
6.82 percent, so the kill line set beforehand (over 10 percent in any month) was not reached. But May is near the low
end by volume: covering every text-type statement takes **18.2 to 42.2 machines** depending on the month, not May's
20.4 to 21.0 alone [COUNTED; machines DERIVED].

## What was read, and how

Seven files, `aggregated-simple-YYYY-MM-01-csv.zip` for 2025-11 to 2026-05, from the address pattern in A28's check
note. For the six new ones: a HEAD request first (1,107,350 to 1,258,781 bytes each, under the 20 MB rule), then the
file into its own new empty directory, then the publisher's `.sha1` file, which equals the SHA-1 of the download in
all six cases. The May file is A28's (same SHA-256). All are read in memory with `python3 -I` and the standard
library, never extracted. The seven files have identical column lists, every flag cell is `true` or `false`, and
each file covers every calendar day of its month. Web searches: 0. Page reads: 0.

The kill line was written into queue item A30 and pushed (commit `2a7fcea71`) before the six files were fetched.

## A28 repeated: platform names by volume class [COUNTED; means DERIVED]

Class = a name's statements in the month divided by the calendar days of the month.

| month | names | statements | mean a day | under 1,000 | 1,000 to 30,000 | over 30,000 | share held by the top class | largest name | top five |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2025-11 | 152 | 608,942,326 | 20,298,077 | 92 | 44 | 16 | 98.01 % | 61.09 % | 84.39 % |
| 2025-12 | 158 | 554,568,436 | 17,889,304 | 103 | 39 | 16 | 97.93 % | 58.99 % | 86.21 % |
| 2026-01 | 166 | 629,515,821 | 20,306,961 | 109 | 41 | 16 | 98.07 % | 50.82 % | 86.24 % |
| 2026-02 | 171 | 589,944,744 | 21,069,455 | 105 | 46 | 20 | 98.18 % | 43.12 % | 81.10 % |
| 2026-03 | 185 | 584,978,404 | 18,870,271 | 123 | 39 | 23 | 98.37 % | 39.78 % | 77.01 % |
| 2026-04 | 186 | 471,510,311 | 15,717,010 | 124 | 41 | 21 | 97.61 % | 50.16 % | 79.81 % |
| 2026-05 | 192 | 491,248,553 | 15,846,727 | 124 | 48 | 20 | 97.54 % | 56.07 % | 81.02 % |

In every month 16 to 23 names file over 30,000 statements a day and hold 97.54 to 98.37 percent of the total; 39 to
48 names are in the middle class and 92 to 124 below it. The number of names grows from 152 to 192.

Across the months: 225 distinct names, 134 of them present in all seven files. 192 names are in the same class in
every month in which they appear; 33 change class at least once.

## A29 repeated: content types [COUNTED; machines DERIVED]

Share of each month's statements that carries the flag (a statement can carry several). Machines: text-type
statements a day divided by 33,750 and by 32,805 requests a day per machine (A25), at one request per statement.

| month | text | text alone | product | other | video | image | text-type a day | machines | names by text-type volume: under 1,000 / 1,000 to 30,000 / over 30,000 | text share held by the top class |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2025-11 | 3.03 % | 2.58 % | 78.84 % | 14.17 % | 2.63 % | 1.34 % | 614,211 | 18.2 to 18.7 | 63 / 26 / 5 | 67.45 % |
| 2025-12 | 4.91 % | 2.66 % | 75.90 % | 14.89 % | 2.68 % | 3.35 % | 877,791 | 26.0 to 26.8 | 73 / 25 / 6 | 83.30 % |
| 2026-01 | 6.82 % | 5.06 % | 63.66 % | 14.10 % | 12.50 % | 4.15 % | 1,384,708 | 41.0 to 42.2 | 76 / 28 / 4 | 85.62 % |
| 2026-02 | 6.05 % | 4.11 % | 65.69 % | 16.91 % | 9.36 % | 3.45 % | 1,274,698 | 37.8 to 38.9 | 77 / 29 / 4 | 81.62 % |
| 2026-03 | 6.04 % | 3.53 % | 69.88 % | 17.89 % | 4.83 % | 3.47 % | 1,139,495 | 33.8 to 34.7 | 85 / 27 / 6 | 84.72 % |
| 2026-04 | 5.57 % | 4.74 % | 68.34 % | 17.81 % | 5.49 % | 1.99 % | 875,331 | 25.9 to 26.7 | 88 / 26 / 5 | 78.98 % |
| 2026-05 | 4.34 % | 3.93 % | 72.21 % | 16.11 % | 5.15 % | 1.85 % | 688,329 | 20.4 to 21.0 | 89 / 30 / 3 | 72.22 % |

Highest text share: 6.82 percent (January 2026). Kill line (over 10 percent in any month): not reached. Product
listings are the largest type in every month (63.66 to 78.84 percent). Each month 25 to 30 names file between 1,000
and 30,000 text-type statements a day, 3 to 6 file more, and 63 to 89 file fewer.

## What changes in the earlier handoffs

- A29 said "20.4 to 21.0 machines" for all text-type statements. That is May. Over the seven months it is 18.2 to
  42.2. The text-type volume a day more than doubles between its lowest month (614,211, November 2025) and its
  highest (1,384,708, January 2026).
- A28's shape (a few names hold nearly everything, most names are far below one machine) is the same in every month.

## Limits

1. The series ends in May 2026. Later months are offered only as Parquet, which the download rule excludes, and the
   website's daily totals over the 50 days to 2026-11-25 are about twice May's (A25, A28).
2. Only May's daily totals were compared with the website's daily table (A28's cross-check). For the other six months
   the check is the publisher's SHA-1 alone, which shows the download is the published file, not that the file agrees
   with the raw data.
3. A name is a string. Whether a name is the same service in two months was not examined, and a name that appears in
   one month and not the next may have stopped filing or been renamed.
4. A25's limits apply to every machine figure: one request per statement, one 128-position chunk, one policy, the
   Nov 22 rate held for 24 hours, public content only.

## A test that would confirm or kill the finding

The same script on a recent month. That needs either a CSV for a month after May (none exists today by A28's HEAD
requests on June and October) or a decision to read the Parquet files. Kill line as before: a text share over 10
percent.

## What was not verified

The six earlier months against the website's daily table or a raw dump; why the totals and the text share move from
month to month; the months after May 2026.
