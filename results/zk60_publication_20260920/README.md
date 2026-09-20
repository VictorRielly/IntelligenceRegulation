# Toy block receipt publication guard — 2026-09-20

`hashline/examples/zk60_private_block.rs` now calls the verifier on the
encoded receipt before creating its output directory or writing receipt and
endpoint policy. This implements D21 at the demo's publication boundary.
The proving API and cryptographic implementation are unchanged.

The real-proof example test passed (one test, no failures or skips):
corrupted and truncated frames leave no directory; an accepted frame and
its exact public endpoint policy are written; a rejected replacement leaves
the accepted receipt intact. The existing verification command also accepts
the 2,816,472-byte receipt and refuses three corruptions.

`run.py` serialized the build and test under `/tmp/zk-build.lock`, using
two threads and the offline locked dependencies. `run.done` is zero;
`validation.json` retains the invocation, 92 source hashes, four pre-existing
proof-binary hashes and the log hash. `audit.json` records an independent
post-run recheck of those pins. Cargo built a hashed example test executable;
the ordinary proof binaries were unchanged.

This is a local publication check for the toy profile, not a model-scale
speed or privacy extension. It does not make the two output writes atomic.
The future multi-block wrapper must stage all segments privately and verify
the entire run before publishing the completed directory.
