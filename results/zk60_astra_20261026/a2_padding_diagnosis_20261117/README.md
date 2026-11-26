# Full-length T256 padding refusal localized

The original 23-step batch compiled and passed its unit tests, text regression,
admission gate and the first complete numerical sequence (item 3122, 234 tokens,
all 26 layers and 18,690,048 historical active words). It stopped on item 3446
at layer 7, before any proof was run. The original failed terminal is preserved.

A separate attention-only reconstruction loads seven small authenticated public
arrays and the retained layer-6 output. It reproduces exactly four score range
violations, with minimum -136 and maximum 52. **All four involve both a padded
query and a padded key.** Three are causal, so ignoring future cells would not
remove the problem. Every score in the original 174-by-174 token square remains
within [-127,127]. Suspect accumulators were also checked using integer dots.
The diagnostic took about 0.06 seconds and peaked below 295 MB; it changed no
calibration, input, native source or proof.

The existing native profile evaluates all 256 positions, including added pad
tokens. A recovery must keep the original prompt and its historical arithmetic,
and explicitly reconcile the native profile's padding semantics. Merely dropping
the refusal, clamping scores, truncating the prompt, or changing calibration
while claiming historical equality would not meet the prepared acceptance gate.
No recovery profile or native proof is qualified by this diagnosis.

The independent full-image replay continues automatically under the same parent
controller. The failure did not require a new user decision or block that work.
Detailed coordinates remain in the private diagnostic named in RESULT.json;
the public report contains counts and its hash, not input text.
