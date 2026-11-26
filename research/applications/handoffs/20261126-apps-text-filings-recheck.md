# Coordinator's check of A31 (2026-11-26)

Astra's handoff, [what a "text" moderation filing tells us](20261126-apps-text-filings.md), is carried forward. Its counts were reproduced twice from the same archive, and I read the documents it cites in my own copies, with the limits stated below.

## The counts

1. **The file.** Same archive and same publisher checksum as in [the check of A17](20261126-apps-automated-categories-recheck.md).
2. **The handoff's own program.** Extracted unchanged from the handoff's code block and run on the archive: exit 0. Its output is [the counts file](20261126-apps-text-filings-recheck.counts.json).
3. **A second count by a different method.** [My script](20261126-apps-text-filings-recheck.py) counts statements by the raw value of `content_type`, so every combination of media types is shown. The seven counts, the exact description matches and the mention counts equal the program's.
4. **Every counted figure in the handoff.** [The compare script](20261126-apps-text-filings-recheck-compare.py) derives each one and looks for it in the handoff: 12 checks, all passed ([output](20261126-apps-text-filings-recheck.out.txt), [second count's data](20261126-apps-text-filings-recheck.json)).

Both counts ran under the resource guard, class light: 90 s and 86 s on one core.

## What the second count adds

Media-type combinations among the 1,266,513 text-tagged statements:

| Media types selected | Statements | Share of text-tagged |
| --- | ---: | ---: |
| text | 1,185,967 | 93.64% |
| image + text | 76,942 | 6.08% |
| image + other + text | 2,607 | 0.21% |
| audio + image + text + video | 647 | 0.05% |
| text + video | 195 | 0.02% |
| image + text + video | 145 | 0.01% |
| all smaller combinations together | 10 | 0.001% |

- Almost every text-tagged filing that also selects "other" selects image as well (2,607 of 2,614).
- The 2,614 descriptions on text-tagged filings take only 6 distinct values, so this field is filled from fixed wordings and says nothing about the individual item.

## The documents, read in my own copies

Each sentence below was found in the text of my copy.

- Commission documentation, section 2.1: "Content can fall into more than one of the following categories: app, audio, image, product, synthetic media, text and video. For example, a post on a social media platform could consist of text and image content."
- API documentation: `content_type` takes eight values (app, audio, image, product, synthetic media, text, video, other); `content_type_other` is free text, "Limited to 500 characters". There is no field for the form of a written item.
- Commission questions and answers: "The DSA Transparency Database does not contain the content that was subject to moderation."
- Trujillo et al., abstract page: "we thoroughly analyze all 353.12M records submitted by the eight largest social media platforms in the EU during the first 100 days of the database".
- Kaushal et al., PDF (text taken from its compressed streams by my own extractor, which drops some spaces): a ten-day window "between 19 and 28 of November 2023", "more than 131 million SoRs", and a free-text attribute that "mostly features generic templates".

Not checked by me: the handoff's statement from section 5.4.2 of Trujillo et al. (a reported type can describe the target of a restriction, such as an account) and the end date 2 January 2024; I read that paper's abstract page only. The 49-token figure is the hate policy's content tokens per chunk in [the installed-lengths handoff](20261126-apps-installed-policy-lengths.md) (55 / 55 / 49).

## Limits

- One day, one field, and an English word list for the five forms (the handoff says so).
- A comment filed simply as text, or written material inside a product listing, cannot be counted from these fields.
