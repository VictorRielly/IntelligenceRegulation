# Applications research queue (Claude applications researcher)

Set by the Claude co-coordinator on 2026-11-24 under the owner's direction D81. One item per tick, first item under
"Open" first. The brief is `CLAUDE_APPLICATIONS_BRIEF.md` beside this file. Business material stays outside the
repository (see the brief).

## Open

1. **The smallest Apple machine that can run the prover for the app's classifier, and its speed (A1).** Reading and
   arithmetic only. A private receipt needs the content holder to run the prover, and today's figures are for one M3
   Ultra with 256 GB. From `results/zk60_resource_guard/history.jsonl` (measured peaks of the classifier serve jobs,
   by label and lane count), the serve flags (`--lanes`, `--lane-threads`, `--witness-cache-gib`) and the lane-scaling
   records named in `docs/zkmatrix-poc/MVP_STATUS.md`: the memory one lane needs, what the witness cache and the
   weights add, and from that a table of machines (unified memory 36, 48, 64, 96, 128 GB) with "fits or not" and an
   ESTIMATE of proved tokens per second at one and two lanes. State the single-lane test under a memory cap on the
   work machine that would confirm the table. Do not run it.
2. **Open-weight detectors of machine-written text that the system could pin and prove (A2).** Web research. A list
   of detectors with public weights (classifier-head models and perplexity-style methods that need only a language
   model's logits), each with size, licence, architecture, published accuracy on a benchmark its authors did not
   build, and known evasion results. For each: does it fit a decoder model of up to 8B with integer arithmetic, what
   exactly a receipt would state, and the proof time for 1,000 and 10,000 tokens at the labelled rate. Closed
   detectors cannot be proved; say which leading ones are closed.
3. **Who runs the prover when the content holder has no suitable machine (A3).** Web research and reading. Options: a
   host the holder trusts by contract; a prover inside a hardware enclave with remote attestation; two-party or
   collaborative proving where no single party sees the input. For each: what privacy statement it supports in plain
   words, what it costs in speed by its authors' numbers, how mature it is, and what our prover would have to change.
4. **Compliance checks on private documents (A4).** Web research. Workflows where a rule or a contract already asks
   for evidence that a named check ran on a document the checker may not see (privilege, personal data, export
   control, policy tags). Which public models of up to 8B exist for such checks, the size of one item, the proof time
   at the labelled rate, and what the receipt would state. Named prospective buyers go to the private file.
5. **Receipts for model evaluations (A5).** Reading and web research. What "model X scored Y on a hidden test set"
   needs from this system (the token input and output stages, the language-model head), what is built and what is
   not per `docs/zkmatrix-poc/MVP_STATUS.md`, the cost of a 1,000-prompt evaluation at the labelled rate, and who has
   published or funded such work.
6. **The provenance route to "human-made" for text (A6).** Reading and web research. `docs/provenance/` describes
   attested capture and a proved edit chain for music. What a text analogue would prove (a committed history of
   edits, typed input events, timestamps), what existing writing-process products record, what stays unprovable (the
   analog hole: retyping machine text), and which parts our existing proof components already cover.

## Done

(none yet)
