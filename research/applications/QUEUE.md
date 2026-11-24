# Applications research queue (Claude applications researcher)

Set by the Claude co-coordinator on 2026-11-24 under the owner's direction D81. One item per tick, first item under
"Open" first. The brief is `CLAUDE_APPLICATIONS_BRIEF.md` beside this file. Business material stays outside the
repository (see the brief).

## Open

4. **Who runs the prover when the content holder has no suitable machine (A3).** Web research and reading. Options: a
   host the holder trusts by contract; a prover inside a hardware enclave with remote attestation; two-party or
   collaborative proving where no single party sees the input. For each: what privacy statement it supports in plain
   words, what it costs in speed by its authors' numbers, how mature it is, and what our prover would have to change.
5. **Compliance checks on private documents (A4).** Web research. Workflows where a rule or a contract already asks
   for evidence that a named check ran on a document the checker may not see (privilege, personal data, export
   control, policy tags). Which public models of up to 8B exist for such checks, the size of one item, the proof time
   at the labelled rate, and what the receipt would state. Named prospective buyers go to the private file.
6. **Receipts for model evaluations (A5).** Reading and web research. What "model X scored Y on a hidden test set"
   needs from this system (the token input and output stages, the language-model head), what is built and what is
   not per `docs/zkmatrix-poc/MVP_STATUS.md`, the cost of a 1,000-prompt evaluation at the labelled rate, and who has
   published or funded such work.
7. **The provenance route to "human-made" for text (A6).** Reading and web research. `docs/provenance/` describes
   attested capture and a proved edit chain for music. What a text analogue would prove (a committed history of
   edits, typed input events, timestamps), what existing writing-process products record, what stays unprovable (the
   analog hole: retyping machine text), and which parts our existing proof components already cover.

## Done

1. **A1, Mac capacity.** The installed app refuses 36–128 GiB under its current admission setting. Sequential one- and two-lane variants have estimated test targets of 48 and 64 GiB respectively. [Measurements and proposed confirmation](handoffs/20261124-apps-classifier-memory.md)
2. **A7, captured-image proofs.** A 12 MP RGB8 witness has 36 million input values. The existing canvas loses some full-resolution changes. End-to-end camera provenance needs a signed capture binding and an edit relation. [Measurements and prover estimates](handoffs/20261124-apps-captured-image.md)
3. **A2, open-weight text detectors.** GLTR needs one 124M decoder and per-token ranks. Binoculars detected 79.6% of unmodified RAID generations at 5% human false positives, falling to 43.5% with synonym substitutions. [Four detectors, costs and calibration test](handoffs/20261124-apps-text-detectors.md)
