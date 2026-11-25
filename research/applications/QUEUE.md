# Applications research queue (Claude applications researcher)

Set by the Claude co-coordinator on 2026-11-24 under the owner's direction D81. One item per tick, first item under
"Open" first. The brief is `CLAUDE_APPLICATIONS_BRIEF.md` beside this file. Business material stays outside the
repository (see the brief).

## Open

11. **Rules that already ask for evidence a receipt could supply (A11).** Web research, added 2026-11-24. For content
    moderation, synthetic-media marking and model audits: which published rules or standards (by article or section,
    with their dates of application) ask a provider for a record that a named check ran, and who is entitled to see
    it. Say for each whether a receipt adds anything over a signed log, and what it cannot supply. No legal advice;
    quote the texts.
13. **What a moderation buyer needs from a label (A13).** Web research, added 2026-11-25 from A10. The installed relation proves one verdict bit; Llama Guard 3, Qwen3Guard, Granite and WildGuard emit categories or several fields. From published platform rules, transparency-report formats and moderation-API documentation, say which uses need the category (or severity tier) and which are served by a verdict bit alone, so the cost of a multi-token label relation can be weighed against need.
14. **Policy-prompt lengths of the named guards (A14).** Local counting, added 2026-11-25 from A10. With the tokenizers' published files (no model weights), count the tokens of the default prompt templates of Llama Guard 3, Qwen3Guard and Granite Guardian for one 40-token input, and compare each with the T = 128 profile and the 72- and 78-token registered Shieldstral policy texts, to say which need a chunk plan or a larger rung. Added by the co-coordinator 2026-11-25T00:21:56Z: also record, for each guard, whether its verdict words (for Llama Guard, `safe` and `unsafe`) are single tokens at the first generated position, because the installed relation compares two token ids.
12. **Where a small proof has to fit (A12).** Web research and counting, added 2026-11-24; a companion to item 90 of
    the efficiency queue. For the places a kilobyte-size proof would be posted or checked (a public blockchain's
    transaction and data limits, a browser, a phone): the size and checking-cost limits by their own documentation,
    and what published proving services for machine-learning inference state as proof size and checking cost.

## Done

1. **A1, Mac capacity.** The installed app refuses 36–128 GiB under its current admission setting. Sequential one- and two-lane variants have estimated test targets of 48 and 64 GiB respectively. [Measurements and proposed confirmation](handoffs/20261124-apps-classifier-memory.md)
2. **A7, captured-image proofs.** A 12 MP RGB8 witness has 36 million input values. The existing canvas loses some full-resolution changes. End-to-end camera provenance needs a signed capture binding and an edit relation. [Measurements and prover estimates](handoffs/20261124-apps-captured-image.md)
3. **A2, open-weight text detectors.** GLTR needs one 124M decoder and per-token ranks. Binoculars detected 79.6% of unmodified RAID generations at 5% human false positives, falling to 43.5% with synonym substitutions. [Four detectors, costs and calibration test](handoffs/20261124-apps-text-detectors.md)
4. **A3, delegated proving.** The current operator can read submitted content. Confidential VMs and collaborative provers have measured costs on other workloads, and each requires a separate classifier qualification. [Trust assumptions, timings and deciding tests](handoffs/20261124-apps-delegated-proving.md)
5. **A4, private document checks.** An auditor can use a filter-execution receipt under a selected cross-domain control. The gateway must separately bind the attachment and filtering result to the transfer. Two open PII taggers need new proof relations. [Requirements, models, sizing and test](handoffs/20261124-apps-private-document-checks.md)
6. **A5, hidden benchmark scores.** A trained 8B receipt reaches one held-out next token. Binding every hidden question and gold answer to the published score is open. Extrapolating one trained CPU run to 1,000 prompts gives 135.4 serial proving hours. [Scoring relation, measurements and published precedents](handoffs/20261124-apps-model-evaluations.md)
7. **A6, writing provenance.** A receipt can authenticate a recorded edit history and the submitted text. A person retyping model output can satisfy the same typing policy as an unaided writer. [Existing recorders, proposed statement and deciding test](handoffs/20261124-apps-writing-provenance.md)
8. **A8, receipt size by workflow.** The guest post downloaded 2.009 GB and its three native checks consumed 128.19 seconds. B6a models about 1.00–1.06 GB for those proofs. Central audit, per-reader replay and aggregate score publication have different requirements. [Five applications and sizing assumptions](handoffs/20261124-apps-receipt-size.md)
9. **A9, video edits.** RGB8 at 30 frames/s gives 186.6 million input values/s at 1080p and 746.5 million at UHD 4K. Two reference calculations matched a two-second crop, redaction and frame-rate conversion. [Counts, published proof measurements and first test](handoffs/20261124-apps-video-edits.md)
10. **A10, safety classifiers.** Llama Guard 3 (1B, 8B) and Nemotron Safety Guard 8B v3 after an adapter merge match the existing block operations; Granite Guardian, Qwen3Guard and ShieldGemma each need new relations, and every generative guard needs a multi-token label relation. [Table of nine models, gaps and test](handoffs/20261125-apps-safety-classifiers.md)
