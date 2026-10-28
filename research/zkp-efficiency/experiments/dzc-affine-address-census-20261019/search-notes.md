# Search assessment — cycle 0083

Native LIVE searches covered current GPU sumcheck/GKR work, affine-address
compilation, and batching/amortization. Exact primary URLs, access dates,
verified publication/history dates, licenses and commit scope are in
`source-records.json`. No downloaded source or build command was executed.

[MLIR's affine documentation](https://mlir.llvm.org/docs/Dialects/Affine/)
and the older [Polygeist paper](https://acohen.gitlabpages.inria.fr/impact/impact2021/papers/IMPACT_2021_paper_1.pdf)
support testing address legality before lowering. They are new to this
research ledger. Our failure applies only to a single translated pointer per
type; general affine expressions or multiple pointers have not been rejected.
No MLIR/Polygeist compiler or reported performance was reproduced.

[Polygeist's repository](https://github.com/llvm/Polygeist) has no displayed
releases. Its actual Apache-2.0-with-LLVM-exception LICENSE was inspected.
The displayed July 31, 2024 commit
[77c04bb2a7a2406ca9480bcc9e729b07d2c8d077](https://github.com/llvm/Polygeist/commit/77c04bb2a7a2406ca9480bcc9e729b07d2c8d077)
concerns ctz builtins, not this optimization. Current HEAD is not established
by cached history.

[Super-sumcheck](https://github.com/ingonyama-zk/super-sumcheck), previously
source 408, and its dated [author explanation](https://www.ingonyama.com/post/sumcheck-201)
separate collapsing arrays from precomputation. This supports accounting for
what is public and reusable versus tied to the witness/challenges. The
repository declares GPL-3.0; actual license and commit-detail fetches failed.
No current release, compatibility or speed claim follows.

[Efficient Sumcheck](https://github.com/compsec-epfl/efficient-sumcheck)
still labels its canonical rewrite unreleased. Its variable-order and
terminal-oracle obligations remain relevant; its changed wire format is not
a drop-in replacement for this project's masked transcript. Actual license,
release and commit-detail fetches failed this cycle; declared Apache/MIT
status and displayed history are kept distinct from inspected terms/HEAD.

The recent [zkLLMPoT v2](https://arxiv.org/abs/2610.08258), October 11, 2026,
remains covered-operator evidence. We did not reproduce its complete privacy
coverage or benchmark and do not convert its operator times to target rates.

New older [BatchZK](https://eprint.iacr.org/2024/1862) targets batch throughput
through pipelined sumcheck, hashing, encoding and transfers. Its workload and
proof system differ. The useful next question is whether our admitted stack's
stage service times and memory lifetimes allow overlap, including fill/drain
and fresh per-proof randomness. Its paper license does not license an
unlocated implementation. Direct PDF open failed; primary landing metadata
and primary PDF search excerpts were readable. No reported proof rate is
adopted as a private 8B token rate.

Next rotation: public setup and batching lifetimes, then GPU NTT/commitments,
lookup/softmax, quantization/arithmetic and proof composition. Retain
sumcheck/GKR and memory-traffic findings; no new paper-list experiment.
