# Transparency-database fields for automated decisions (A15)

**Question.** In the DSA statement-of-reasons database schema: which fields describe automated detection and decision, could any carry a reference to a receipt, what does the database refuse to hold, and is there a field for the one use A11 found (a recipient or the Commission checking an automated verdict without the content)? Also: where the provider may not keep or pass on the content, is a receipt made at decision time the only checkable record? Confirm or correct the co-coordinator's recollection that the schema has fields for automated detection and automated decision.

**Answer in one line.** The recollection is confirmed: `automated_detection` (Yes/No) and `automated_decision` (three values) are required fields. Nothing else in the schema names a model, version, policy or evidence reference, and no field is made for a receipt. A pointer could only go in free text (`decision_facts`, 5,000 characters), which nobody checks. The database refuses personal data and does not hold the content. The "nobody can rerun" case exists for content past a legal retention window, but I could confirm only the first half (a bounded retention rule); an unlawful-to-hold case is not verified.

## What was read and how

4 web searches (standard) and 6 page fetches, within budget. The fetch tool returns model-written summaries, not raw page text; field names and quotations are as returned and should be checked against the live pages before anyone relies on wording. Nothing was run. Pages: the Commission's [API and Schema page](https://transparency.dsa.ec.europa.eu/page/api-documentation) (schema updated 1 July 2025), [Additional Explanation For Statement Attributes](https://transparency.dsa.ec.europa.eu/page/additional-explanation-for-statement-attributes), the [Commission FAQ](https://digital-strategy.ec.europa.eu/en/faqs/dsa-transparency-database-questions-and-answers), the [consolidated DSA](https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32022R2065) (characters 200,000 to 300,000 only, for Arts. 17, 20, 24), the [Terrorist Content Regulation Art. 6 in German](https://gesetze.legal/eu/vo_eu_2021_784/6) (secondary).

## Findings

Labels: [page] = the Commission page as returned by the fetch tool.

**Automation fields.** [page, API and Schema]
- `automated_detection` (required): "Yes" or "No". [page, explanation] "'Yes' means that automated means were used to identify the specific information addressed by the decision." Only "Yes" is defined.
- `automated_decision` (required): `AUTOMATED_DECISION_FULLY`, `_PARTIALLY`, `_NOT_AUTOMATED`. [page, explanation] Fully = "the entire decision-process was carried out without human intervention"; partially = "both automated means and human interaction were applied".
- Correction to the recollection: the explanation page's own sentence for both ("indicates whether and to what extent automated means were used") promises more than the two fields give; neither names the system, version or what the automation did. Nothing distinguishes a classifier from a hash match or a keyword rule.

**Fields that could hold a reference** (all free text or an identifier, none checked against anything). [page, API and Schema]
- `decision_facts`: required, free text, 5,000 characters, "facts and circumstances relied on"; the explanation page says "Platforms are encouraged to use standard language for similar cases." This is the only realistic place for a receipt reference.
- `decision_ground_reference_url`: optional URL "to the TOS or Law relied upon" (meant for the rule, not evidence).
- `incompatible_content_ground` (500 characters, "reference to contractual grounds"), `incompatible_content_explanation` and `illegal_content_explanation` (2,000 characters each), `source_identity` (500).
- `puid`: platform-unique id, up to 500 characters of letters, digits, hyphens and underscores; an identifier, not for evidence.
- `content_id`: the only foreseen key is EAN-13 (product identifiers). No input-commitment field.
- `category` (one of 16 values), `category_addition`, `category_specification`: carry the category, not how it was decided (A13).

**What the database refuses or lacks.**
- Personal data: "When submitting statements please take care to not submit ANY personal data"; providers must ensure the information "does not contain personal data" (Art. 24(5), as read). [page; DSA]
- Content: "The DSA Transparency Database does not contain the content that was subject to moderation." [FAQ]
- The pages read state no other prohibition, no signature or attachment field, and no check of any claim. The FAQ does not say whether a provider can edit or remove a submitted statement.
- Visibility: statements are searchable from the day after submission until 180 days later; daily dumps are kept 18 months; dashboard aggregates 5 years. [FAQ]

**Is there a field for A11's one use?** No dedicated field. The use (a recipient, complaint body or the Commission checks that a pinned model gave a stated verdict on a committed input) needs: a model hash, a policy id, an input commitment and a verdict, each machine-readable. The schema has none; they would be text in `decision_facts` or a link elsewhere. Art. 20(1) [DSA, as read]: the complaint system must stay open "for a period of at least six months following the decision". That period is the window in which a receipt would be examined, and it roughly matches the 180-day search window. DERIVED: 6 months is about 182 days.

**Cases where nobody can rerun the model.** DERIVED from the texts, not asserted by them.
- Rerunning needs the content (or its recorded copy), the open pinned model and the policy. A receipt made at decision time needs none of the content afterwards.
- Terrorist Content Regulation (EU) 2021/784 Art. 6, as read (German, secondary summary): removed content and related data are kept six months after removal for review and complaints, extendable only by order while review is ongoing, for access only for those purposes. So under that regulation a rerun is possible for six months, then not required. Art. 6 was not read in the Official Journal.
- Content deleted on a user's request, past a provider's own retention limit, or unlawful to hold (for example abuse material): I did not verify any provision requiring deletion in the DSA or elsewhere. A search for the interim child-abuse detection regulation (2021/1232) returned nothing on retention or deletion. So "unlawful to hold" is a hypothesis.
- Also needed for the receipt to be the only record: the provider must have run the pinned open model at decision time. Most deployed moderation is proprietary or non-integer; for those a receipt does not exist and the case is not served.

## What a product would have to build

A decision-time step that runs the pinned classifier under the prover on the item before deletion; a record carrying model hash, policy id, input commitment, verdict and receipt hash; a place to post it (the schema offers only `decision_facts` or a link in free text); a verifier a complaint body can run; and a statement of what the commitment reveals (a hash of content that is itself personal data may still count as personal data; not verified, a legal question).

## A test that would confirm or kill the finding

Take ten items from the installed classifier's calibration set. For each, write a statement-of-reasons payload in the real schema, with the receipt reference placed only in `decision_facts`. Delete the item. Give the payload to a reviewer who must decide whether the stated automated verdict was the pinned model's. **Confirmed** if they can check it with the installed verifier unchanged and without the item, and the payload passes the schema as written (5,000 characters suffice). **Killed** if the verifier needs the committed input at check time, or the reference does not fit within the limits.

## What was not verified

Raw schema field tables (summaries only); the old (pre-July 2025) schema; whether the database validates `decision_facts` content; whether providers may edit statements; Official Journal text of Reg. 2021/784 Art. 6, DSA Arts. 17, 20 and 24 beyond the slices read; any deletion or no-retention duty (GDPR Art. 17, abuse-material rules, national law); whether a content commitment is personal data; how often automated statements actually occur (item 17). The search tool is US-only.
