# Share of statements of reasons whose content type is text (A29)

**Question.** Which content types does the EU transparency database allow, and what share of statements of reasons
carries the text type, against products, video, images and the rest? What could the installed text classifier cover
and what could it not? Done by the co-coordinator as a local count on the file that A28 fetched (no agent). Script
`20261126-apps-text-share.py`, output `20261126-apps-text-share.out.txt` (prints each input's sha256, re-checks every
quotation, and prints no clock reading, no path and no platform name). Business material: none written. No platform
is named; no target is recommended.

**Answer in one line (May 2026).** 21,338,219 of the month's 491,248,553 statements carry the text type: **4.34
percent**, about 688,000 a day [COUNTED]. 72.21 percent carry the product type. At one request per statement, all
text-type statements of the month come to **20.4 to 21.0 machines** [DERIVED from A25's machine rate].

## What was read, and how

- The database's API documentation page, https://transparency.dsa.ec.europa.eu/page/api-documentation (raw HTML,
  104,565 bytes, fetched 2026-11-26 into its own directory, read as text).
- The documentation page of the aggregated files,
  https://dsa.pages.code.europa.eu/transparency-database/dsa-tdb/data_sources.html (the copy fetched for A25; same
  hash as A28's).
- The aggregated file of A28: `aggregated-simple-2026-05-01-csv.zip`, 1,198,577 bytes, sha256 `385aec62...`, read in
  memory and never extracted. A28's check applies to it: the publisher's SHA-1 matches, and its 31 daily totals
  agree with the website's daily table to within 0.05 percent on every day.
- Web searches: 0. Page reads: 1 new (the API page).

## The allowed values [SOURCE; both sentences re-found by the script]

API page, "Content type (content_type)": "This is a required attribute, and it tells us what type of content is
targeted by the statement of reason. The value provided must be an array with at least one of the following:
CONTENT_TYPE_APP App CONTENT_TYPE_AUDIO Audio CONTENT_TYPE_IMAGE Image CONTENT_TYPE_PRODUCT Product
CONTENT_TYPE_SYNTHETIC_MEDIA Synthetic media CONTENT_TYPE_TEXT Text CONTENT_TYPE_VIDEO Video CONTENT_TYPE_OTHER
Other". So there are eight values, a statement must carry at least one, and it may carry several.

Same page, "Content type other (content_type_other)": "This is required if CONTENT_TYPE_OTHER was the content_type.
It is a content type that is not part of provided content type list. Limited to 500 characters."

Aggregated-files page: "All the array fields like content_type or decision_visibility are pivoted, that is, for each
one of their possible values a new column is created and filled with a boolean, indicating whether the SoR has that
value or not." And: "The content_type field is pivoted and we also add the
dsa_tdb.types.CONTENT_TYPE_OTHER_NORMALIZATION additional values. These values are meant to map recurring values
found in the content_type_other field to standardized values."

The file has 13 flag columns: the eight above and five more (LINK, ACCOUNT, AD, STICKER, HASHTAG). Every statement
with one of the five also has OTHER set (74,572,159 of 74,572,159) [COUNTED], which fits the page's description of
them as standardised readings of the free-text "other" field.

## What is counted

One row of the file is one combination of its fields; its `count` column is the number of statements in that
combination ("The count of SoRs is reported in the count column."). A statement "carries the text type" when its row
has `CONTENT_TYPE_TEXT` true. The type is what the platform reported as the content its decision targeted. Period:
2026-05-01 to 2026-05-31, all 31 days present. Every flag cell is `true` or `false`.

## Counts [COUNTED from the file]

| content type | statements | share of the month |
|---|---:|---:|
| product | 354,721,683 | 72.21 % |
| other | 79,127,280 | 16.11 % |
| of which account (added column) | 36,215,080 | 7.37 % |
| of which link (added column) | 29,663,861 | 6.04 % |
| of which ad (added column) | 8,166,385 | 1.66 % |
| video | 25,287,854 | 5.15 % |
| **text** | **21,338,219** | **4.34 %** |
| image | 9,068,856 | 1.85 % |
| synthetic media | 3,316,325 | 0.68 % |
| audio | 456,886 | 0.09 % |
| app | 152,605 | 0.03 % |

The shares add to 115.63 percent because a statement can carry several types: 84.40 percent carry one flag, 15.57
percent two (mostly "other" with one of its added columns), 0.03 percent three or more.

**Text.** Text alone: 19,314,628 statements, 3.93 percent of the month and 90.52 percent of the text-type
statements. Text with another type: 2,023,591, of which 2,014,941 also carry the image type (9.44 percent of the
text-type statements). No text flag: 469,910,334, or 95.66 percent. Text-type statements per day: mean 688,330, lowest day
571,937, highest day 845,645.

**Who files them (counts by class only).** 122 of the 192 platform names filed at least one text-type statement.
Grouped by text-type volume alone, on a 31-day mean: 89 names under 1,000 a day (0.92 percent of text-type
statements), 30 names from 1,000 to 30,000 (26.87 percent), 3 names over 30,000 (72.22 percent). The largest name
holds 44.40 percent of the text-type statements and the top five 78.92 percent. By A28's classes (all statements):
the 124 smallest names file 0.69 percent of the text-type statements, the 48 in the middle 14.20 percent, the 20
largest 85.11 percent; text is 41.83 percent of what the smallest class files, 25.82 percent of the middle class and
3.79 percent of the largest.

**By reported category.** The file's `category` column for the text-type statements: other violation of the
provider's terms and conditions 43.89 percent, illegal or harmful speech 20.64 percent, scams and fraud 20.19
percent, unsafe or prohibited products 3.91 percent, violence 3.10 percent, consumer information 3.07 percent, data
protection and privacy 1.54 percent, cyber violence 1.31 percent, and eight smaller ones (full table in the output).
The API page lists 16 categories, the file uses all 16, and none has a name for sexual content.

## Against the machine rate [DERIVED; one request per statement, one chunk, one policy]

A25's rate is 32,805 to 33,750 requests a day per machine (MEASURED 48.6 to 50.0 tokens/s on Nov 22, scaled to 24
hours by arithmetic; no day-long run exists).

- All text-type statements: 688,330 a day, 20.4 to 21.0 machines. Text alone: 623,053 a day, 18.5 to 19.0 machines.
- The 89 names with under 1,000 text-type statements a day, together: 6,311 a day, 0.19 of one machine.
- The 30 names from 1,000 to 30,000, together: 184,934 a day, 5.5 to 5.6 machines.
- The 3 names over 30,000, together: 497,084 a day, 14.7 to 15.2 machines.
- So 119 of the 122 names that filed text-type statements each filed fewer a day than one machine proves.

## What the installed text classifier could cover, and what it could not

It could cover at most the text-type statements: 4.34 percent of the month. It could not cover the 95.66 percent
without the text flag: product listings (72 percent), accounts, links and ads reported under "other", video, images,
synthetic media, audio and apps. For the 9.44 percent of text-type statements that also carry the image type, it
would see the text only.

Within the text-type statements, the installed app screens three policies (sexual, violence, hate; the three
inventories counted in A27). The database's categories do not line up with them. The four categories with "speech"
or "violence" in their name hold 5,343,881 text-type statements, 25.04 percent, about 172,000 a day or 5.1 to 5.3
machines [DERIVED]. That is a grouping by name only: no mapping between a database category and a policy of the
classifier has been validated, and the largest category, "other violation of terms and conditions" (43.89 percent),
says nothing about the kind of text.

## Limits

1. May 2026, not a recent month. The website's daily totals over the 50 days to 2026-11-25 are about twice May's
   (A28), and the mix of content types in those months was not read.
2. The type is self-reported by each platform, and platforms may apply the values differently. A name in the file
   is a string, not necessarily one company or one service.
3. A statement records a decision that was filed. How many items a platform screens to reach those decisions is not
   in the file.
4. One request per statement assumes the text fits one 128-position chunk under one policy (A22, A25). The file
   says nothing about the length of the text; A24 is the open item on that.
5. The installed profile is "Public content only; privacy not claimed". A verdict is a statistical screen. What a
   receipt proves is that this pinned model, run on this input, gave this verdict.

## A test that would confirm or kill the finding

Run the script on the aggregated file of another month (A28 reports that CSV files exist for 2025-11 to 2026-05,
1.11 to 1.26 MB each; only May was fetched and checked). The finding "text is a small share" is killed if the text
share exceeds 10 percent in any of those months (queue item A30). A recent month would need the Parquet twin, which the download rule does not allow yet.

## What was not verified

- Any month other than May 2026, and any day's raw dump.
- How platforms decide which type to report, and whether "text" covers posts, comments, messages, reviews or listing
  descriptions.
- Any mapping between the database's categories and the installed classifier's three policies.
- The five added columns' definition beyond the page's sentence (the package's code was not read).
- A17 (the category mix of automated statements) is a separate, claimed item; the file also has
  `automated_detection` and `automated_decision` columns, which were not crossed with content type here.

## Follow-up (A30, 2026-11-26)

The same count was repeated on the six earlier monthly files. Over November 2025 to May 2026 the text share is 3.03 to 6.82 percent (kill line not reached) and the text-type statements are 614,211 to 1,384,708 a day, which is 18.2 to 42.2 machines; May is near the low end. See `20261126-apps-months-check.md`.
