# Applications research queue (Claude applications researcher)

Set by the Claude co-coordinator on 2026-11-24 under the owner's direction D81. One item per tick, first item under
"Open" first. The brief is `CLAUDE_APPLICATIONS_BRIEF.md` beside this file. Business material stays outside the
repository (see the brief).

## Open

7. **The provenance route to "human-made" for text (A6).** Reading and web research. `docs/provenance/` describes
   attested capture and a proved edit chain for music. What a text analogue would prove (a committed history of
   edits, typed input events, timestamps), what existing writing-process products record, what stays unprovable (the
   analog hole: retyping machine text), and which parts our existing proof components already cover.
8. **Receipt size and checking time each application can tolerate (A8).** Reading and derivation, added 2026-11-24
   after the owner's ruling D82. For each application studied so far (submissions of unpublished text, peer review,
   captured images, private document checks, hidden benchmark scores): who stores the receipt, who downloads it, how
   often it is checked and on what machine. Set against that the measured sizes of today's receipts and the modelled
   sizes of the size steps in `docs/zkmatrix-poc/ZK60_SIZE_B6A_BUILD_PLAN_20261124.md` (label each MEASURED or MODEL).
   The result is a table that says which application is served by which size step, and which needs a step that is
   only at study level.
9. **Video (A9).** Web research and counting, added 2026-11-24 from the owner's capture idea. The image study (A7)
   counted one 12-megapixel frame. For video: the committed cells per second of 1080p and 4K footage, which edits have
   a proof relation of bounded cost (cut, crop, redaction of a region, a change of frame rate) and which do not
   (re-encoding with a lossy codec), what published systems for proved image and video edits report by their authors'
   numbers, and what a first test on a few seconds of synthetic footage would be.

## Done

1. **A1, Mac capacity.** The installed app refuses 36–128 GiB under its current admission setting. Sequential one- and two-lane variants have estimated test targets of 48 and 64 GiB respectively. [Measurements and proposed confirmation](handoffs/20261124-apps-classifier-memory.md)
2. **A7, captured-image proofs.** A 12 MP RGB8 witness has 36 million input values. The existing canvas loses some full-resolution changes. End-to-end camera provenance needs a signed capture binding and an edit relation. [Measurements and prover estimates](handoffs/20261124-apps-captured-image.md)
3. **A2, open-weight text detectors.** GLTR needs one 124M decoder and per-token ranks. Binoculars detected 79.6% of unmodified RAID generations at 5% human false positives, falling to 43.5% with synonym substitutions. [Four detectors, costs and calibration test](handoffs/20261124-apps-text-detectors.md)
4. **A3, delegated proving.** The current operator can read submitted content. Confidential VMs and collaborative provers have measured costs on other workloads, and each requires a separate classifier qualification. [Trust assumptions, timings and deciding tests](handoffs/20261124-apps-delegated-proving.md)
5. **A4, private document checks.** An auditor can use a filter-execution receipt under a selected cross-domain control. The gateway must separately bind the attachment and filtering result to the transfer. Two open PII taggers need new proof relations. [Requirements, models, sizing and test](handoffs/20261124-apps-private-document-checks.md)
6. **A5, hidden benchmark scores.** A trained 8B receipt reaches one held-out next token. Binding every hidden question and gold answer to the published score is open. Extrapolating one trained CPU run to 1,000 prompts gives 135.4 serial proving hours. [Scoring relation, measurements and published precedents](handoffs/20261124-apps-model-evaluations.md)
