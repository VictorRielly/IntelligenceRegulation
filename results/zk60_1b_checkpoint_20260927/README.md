# Public trained checkpoint acquisition

This directory retains immutable source metadata and acquisition evidence
for the approximately 1B intermediate checkpoint. Only public model files
are involved. No private prompt, activations or proof witness belongs here.

Candidate: the official `TinyLlama/TinyLlama-1.1B-Chat-v1.0` repository,
subject to the model lane's compatibility and layout gate. The full BF16
checkpoint is expected to be about 2.2 GB; the tensor header and provider
digest must establish its exact bytes and parameter count. Do not substitute
the FP32 base checkpoint without changing source identity and memory counts.

A successfully downloaded tensor file is not a calibrated model or a proof.
See `docs/zkmatrix-poc/ZK60_1B_CHECKPOINT.md` for the remaining gates.
