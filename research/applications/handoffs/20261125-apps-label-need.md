# What a moderation buyer needs from a label: category, severity tier or a verdict bit (A13)

**Question.** The installed relation proves one verdict bit (a tied yes/no margin after a fixed suffix). Most open guards emit categories or several fields (A10). From published rules, report formats and moderation-API documentation: which uses need the category or a severity tier, and which are served by a bit alone, so the cost of a multi-token label relation can be weighed against need.

**Answer in one line.** Every public format read asks for a category (the DSA statement-of-reasons database and transparency templates make it mandatory), but none requires the category to be the output of a classifier, and the installed relation can already carry a category if the category is fixed by the registered policy (one question per category, one bit per question). A multi-token label relation is needed only where one run must pick among categories or tiers; the price of the alternative (n policy runs for n categories) was not measured. Nothing was run.

## What was read and how

8 web searches (standard mode) and 6 page fetches, within budget. Fetched: the DSA transparency database API page (twice, the second for the value lists), the arXiv paper analysing the database, Implementing Regulation (EU) 2024/2835 on EUR-Lex (two slices), and the Microsoft Learn severity-level page. Others (OpenAI moderation reference, YouTube transparency report, NCMEC) rest on search-result summaries only. The fetch tool returns model-written summaries, not raw text. Local reading: the A10 and A11 handoffs, nothing else. Queue item 15 (DSA schema, A15) is partly answered by finding 2 below: both automated fields exist; the rest of A15 is open.

## Findings

Labels: [page] = what the fetched page said as the tool returned it; [snippet] = search-result summary only.

**1. Reporting formats that require a category (the category is a field, not a model output).**
- DSA transparency database, attribute `category`: required, one of 16 `STATEMENT_CATEGORY_*` values; optional `category_addition` and an array `category_specification` of `KEYWORD_*` values (69 listed, counted from the fetch result, which may have dropped or merged entries) [page: https://transparency.dsa.ec.europa.eu/page/api-documentation]. Fixed-option values, so a category is a closed list; free text is limited to 500 characters for grounds and 5,000 for `decision_facts`.
- Implementing Regulation 2024/2835 Annex I: own-initiative measures are reported per illegal-content category (numbered up to 14, with lettered sub-categories, for example 14a to 14f for violence), per terms-and-conditions category (15, with 15a to 15g, for example adult sexual material, nudity) and two fallback categories (16, 17); each row also gives "number of measures taken after detection with solely automated means" [page: https://eur-lex.europa.eu/eli/reg_impl/2024/2835/oj/eng]. The first 13 category names were cut off by the fetch.
- YouTube's enforcement report breaks removals down by reason; the removal reason is assigned by a reviewer when automation flags content, and exact-match re-upload blocks and some older tool removals carry no reason at all [snippet: https://support.google.com/transparencyreport/answer/9209072]. So in at least one large pipeline the category is a human step after an automated flag.
- NCMEC CyberTipline: the reporter selects an incident type (child sex trafficking, online enticement, child pornography, and others); the REPORT Act (enacted 7 May 2024) added two reportable categories [snippet: https://www.missingkids.org/content/dam/missingkids/pdfs/ncmec-support-report-it-act.pdf]. The field list was not found.

**2. Fields that need no category (a bit or enum is enough).**
- `automated_detection` (required): "Yes" or "No". `automated_decision` (required): `AUTOMATED_DECISION_FULLY`, `_PARTIALLY` or `_NOT_AUTOMATED` [page]. These record whether automation was used, not what it labelled. There is no field for a model identifier, score or receipt.
- Annex I's automated-means rows: counts solely automated, counts not automated, and accuracy, precision and recall; the text gives no formula and says rows are reported "as floating numbers in the [0,1] interval" [page]. These need human-labelled ground truth, which no classifier label supplies.

**3. Severity tiers.** Microsoft's guardrail service grades four harm categories (hate and fairness, sexual, violence, self-harm) at four levels (safe, low, medium, high); a customer sets a blocking level per category: "Low" blocks high only, "Medium" blocks medium and high, "High" blocks low, medium and high; safe is annotated, never blocked [page: https://learn.microsoft.com/en-us/azure/foundry/openai/concepts/content-filter-severity-levels]. The buyer's decision is a threshold on a tier, per category. OpenAI's moderation response gives a boolean per category, a 0 to 1 score per category and one overall `flagged` boolean, and says the model is upgraded in place so thresholds may need recalibration [snippet: https://developers.openai.com/api/docs/guides/moderation]. The guide suggests checking `flagged` first as a quick decision, which is a single bit [snippet].

## What the installed relation can and cannot carry (DERIVED)

DERIVED from A10's description of the relation (one policy text, one comparison of two token ids).
- **Category fixed by policy.** If the registered policy is "does this text contain hate speech", a yes verdict is the category claim. For a statement of reasons that names one category, one bit per policy suffices. The cost is the number of policies a provider runs per item: n categories means n runs, each a full forward pass over the item plus its policy text. I have no measurement of this against a k-token decode and did not assume one is cheaper.
- **Severity tier.** A tier threshold is a bit per threshold (is it at least medium). Four tiers of four categories needs up to 12 threshold policies per item, DERIVED (three non-trivial thresholds times four categories), unless a buyer fixes one threshold per category, which reduces it to 4.
- **Choice among categories in one run.** Needs a label relation over several tokens or a multi-class head. Of the fields above, only a requirement to produce the category from the content in one pass (a buyer who does not know in advance which of 16 applies) needs it.
- **Cannot be supplied by either design:** that the policy text is the category the rules mean; that classifier categories match the 16 DSA values (they do not map one to one: Llama Guard's S1 to S14 versus the 16 `STATEMENT_CATEGORY_*` values was not compared); human confirmation (YouTube's reason is human).

## What a product would have to build

1. A policy registry whose entries carry a mapping to the buyer's reporting category, for example one registered question per DSA category the buyer actually uses.
2. A record format with the receipt reference beside `category`, `automated_detection` and `automated_decision`. The DSA schema has no model or receipt field; the closest are the free-text `decision_facts` (5,000 characters) and `decision_ground_reference_url` (a URL to terms or law, not to a receipt). Whether a receipt reference there would be accepted was not tested.
3. Only if a buyer needs one-pass category choice: the multi-token label relation from A10.

## A test that would confirm or kill the finding

Take one day's public statements-of-reasons file from the DSA database (zipped CSV, public) and count, for rows with `automated_detection` = Yes, the share by `category`. **Confirmed** (bit per policy suffices for most) if most automated rows fall in a few categories that each correspond to a single yes/no question a registered policy could ask (for example scams and fraud, adult sexual material, violence). **Killed** if most automated rows have `category_addition` set, or sit in `OTHER_VIOLATION_TC` or `NOT_SPECIFIED_NOTICE`, so no single question names them. Then measure n policy runs against one template on the installed relation, with the quiet-box conditions in `MVP_STATUS.md`.

## What was not verified

Categories 1 to 13 of Annex I (cut off by the fetch) and the legal text of Articles 15, 17 and 24(5) in raw form this tick (A11 read them as summaries); whether providers actually fill `category` from a classifier or by hand beyond YouTube's description, which is a search snippet; OpenAI's category list and NCMEC's required fields; any per-category share of automated statements (the arXiv paper reports only per-platform patterns, in prose, section 5.2); whether a classifier's categories can be mapped to the DSA's 16; costs of n policy runs.
